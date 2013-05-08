#!/bin/bash

#### jenkins job:  changelog-report 
# 
# build parameters:
# 
# LAST_BLD   - build number of last build in survey period
# FIRST_BLD  - build number of first build in survey period
# 
# BRANCH     - which branch these changes occur on

PROJECTS="couchbase-cli couchdb couchdbx-app couchstore ep-engine geocouch membase-cli ns_server testrunner tlm"

FAILS=0

HTTP=http://builds.hq.northscale.net/latestbuilds

PKG_ROOT=couchbase-server-enterprise_x86_64

GITLOG='--pretty=format:--------------------------------------------------%ncommit: %H%nAuthor: %an < %ae >%nDate:   %cd%n%n%s%n%n%b'
GIT_URL=git://builds.hq.northscale.net

TRUE=0
FALSE=1

USAGE="\nuse:\t"'export LAST_BLD=nnnn ; export FIRST_BLD ; export BRANCH ; changelog.sh'"\n\n"
USAGE=${USAGE}"\t"'will compute changes between builds <BRANCH>-<LAST_BUILD> and <BRANCH>-<FIRST_BUILD>'"\n\n"
USAGE=${USAGE}"\t"'where LAST_BUILD > FIRST_BUILD'"\n\n"

INT_REX='^[0-9]+$'
CRX_REX='(current.xml)$'
    
function isInt
    {
    value=$1
    
    if [[ $value =~ $INT_REX ]]
      then
        RANGE=${BASH_REMATCH[1]}
        echo $TRUE
      else
        echo $FALSE
    fi
    }

function write_log
    {
    LOG_DIR=$1
    LOGFILE=$2
    LOG_MSG=$3
    
    OPT_ARG="";  if [[ $4 ]] ; then OPT_ARG=$4 ; fi
    
    if [[ ! -d ${LOG_DIR} ]]
        then
        mkdir  ${LOG_DIR}
        echo ---------------------------------------------------- mkdir: ${LOG_DIR}
    fi                    
    echo  ${OPT_ARG}  "${LOG_MSG}">> ${LOG_DIR}/${LOGFILE}
    echo  ${OPT_ARG}  "${LOG_MSG}"
    }

function sort_bnums
    {
    if [[ ${LAST_BLD} == ${FIRST_BLD} ]] ; then echo -e $USAGE; exit 88; fi
    
    if [[ `isInt ${LAST_BLD}` == $TRUE && `isInt ${FIRST_BLD}` == $TRUE ]]
        then
        if [[ ${LAST_BLD} < ${FIRST_BLD} ]]
            then
            SWAP=${LAST_BLD}
            LAST_BLD=${FIRST_BLD}
            FIRST_BLD=${SWAP}
        fi
    fi
    if [[ ${FIRST_BLD} =~ $CRX_REX ]]
        then
            SWAP=${LAST_BLD}
            LAST_BLD=${FIRST_BLD}
            FIRST_BLD=${SWAP}
    fi
    LAST_BLD_NAME=${LAST_BLD}  ;  if [[ ${LAST_BLD}  =~ $CRX_REX ]] ; then LAST_BLD_NAME=current ; fi
    }
sort_bnums


#echo 'calling sort_bnums()'
#echo "DEBUG: LAST_BLD      = ${LAST_BLD}"
#echo "DEBUG: LAST_BLD_NAME = ${LAST_BLD_NAME}"
#echo "DEBUG: FIRST_BLD     = ${FIRST_BLD}"

REPORTS=${WORKSPACE}/${LAST_BLD_NAME}-${FIRST_BLD} 
if [[ -d ${REPORTS} ]] ; then rm -rf ${REPORTS} ; fi
mkdir    ${REPORTS}

DELTA_DIR=changelog
NO_CHANGE=no_change
ERROR_DIR=git_errors

CHANGES=${REPORTS}/${DELTA_DIR}
NO_DIFF=${REPORTS}/${NO_CHANGE}
ERRRORS=${REPORTS}/${ERROR_DIR}

function fetch_manifest
    {
    bld_num=$1
    
    bld_num=`echo $bld_num  | sed 's/^ *//g' | sed 's/ *$//g'`

    branch=${BRANCH}
    if [[ ${BRANCH} == 'master' ]] ; then branch=2.1.0 ; fi
    
    pushd ${REPORTS}     > /dev/null
    
    if [[ ${bld_num} =~ $CRX_REX ]]    # instead of build number, pass in absolute path to current.xml
      then                             # This is for use by buildbot jobs.
        filename=${BASH_REMATCH[1]}
        cp ${bld_num} ${filename}
        manifest=${filename}
        echo ${manifest}
        return 0
      else
        for sufx in deb rpm setup.exe
          do
          manifest=${PKG_ROOT}_${branch}-${bld_num}-rel.${sufx}.manifest.xml
          
          wget  ${HTTP}/${manifest} ; STATUS=$?
          
          if [[ ${STATUS} == 0 ]]
              then
              echo ${manifest}
              return 0
          fi
        done
      fi
    popd             > /dev/null
    return 99
    }

function get_rev
    {
    manifest=$1
    component=$2

    grep \"${component}\" ${REPORTS}/${manifest} | tr ' ' "\n" | grep revision | awk -F\" '{print $2}'
    }


echo ---------------------------------------------- cleaning workspace: ${WORKSPACE}
rm ${PKG_ROOT}*.manifest.xml

echo ---------------------------------------- getting manifest for build ${LAST_BLD_NAME}
MFST_1ST=`fetch_manifest ${LAST_BLD}`
if [[ $? > 0 ]]
    then
    echo ======== could not find manifest for build: ${BRANCH}-${LAST_BLD_NAME}
    exit 99
fi
echo ---------------------------------------- ${MFST_1ST}

echo ---------------------------------------- getting manifest for build ${FIRST_BLD}
MFST_2ND=`fetch_manifest ${FIRST_BLD}`
if [[ $? > 0 ]]
    then
    echo ======== could not find manifest for build: ${BRANCH}-${FIRST_BLD}
    exit 99
fi
echo ---------------------------------------- ${MFST_2ND}

echo -------------------------------------------- comparing manifests
echo ${MFST_1ST}
echo ${MFST_2ND}
echo -------------------------------------------- 


for COMP in ${PROJECTS}
  do
  echo ---------------------------------------------- ${COMP}
  if [[ -d ${COMP} ]]  ;  then rm -rf ${COMP} ; fi
    
  #  BASE=couchbase
  #  if [[ ${COMP} == membase-cli ]] ; then BASE=membase ; fi
  #  if [[ ${COMP} == memcached   ]] ; then BASE=membase ; fi
  
  THIS_FAIL=0
      
  REV_1ST=`get_rev ${MFST_1ST} ${COMP}`
  REV_2ND=`get_rev ${MFST_2ND} ${COMP}`
  
      
  OUT=${COMP}-GIT-ERROR.txt
    
  MSG=`git clone  ${GIT_URL}/${COMP}.git 2>&1`  ;  STATUS=$?
  
  if [[ $STATUS > 0 ]]
    then
      write_log              ${ERRRORS}  ${OUT}  "GIT ERROR: unable to clone ${GIT_URL}/${COMP}.git"
      THIS_FAIL=$STATUS
    else
      pushd ${COMP}      > /dev/null
      echo "clone ready: ${GIT_URL}/${COMP}.git"
      sleep 1
      if      [[ ! `git branch --all | grep ${BRANCH}` ]]
        then
          write_log          ${ERRRORS}  ${OUT}  "Project ${COMP} has no branch ${BRANCH} on github"
        # THIS_FAIL=1
        else
          if [[ ${BRANCH} == master ]] ; then CHECKOUT='checkout'
                                         else CHECKOUT='checkout -b' 
          fi
          MSG=`git ${CHECKOUT} ${BRANCH} origin/${BRANCH}`  ;  STATUS=$?
          
          if [[ $STATUS > 0 ]]
            then
              write_log      ${ERRRORS}  ${OUT}  "GIT ERROR: unable to checkout branch ${BRANCH} of ${COMP}"
              THIS_FAIL=$STATUS
            else
              OUT=${COMP}-changelog-${BRANCH}-${LAST_BLD_NAME}-${FIRST_BLD}.txt
              
              RANGE="${REV_2ND}..${REV_1ST}"
              if [[  ${REV_2ND} == ${REV_1ST} ]]
                then
                  OUT=${COMP}-NO-CHANGE-${BRANCH}-${LAST_BLD_NAME}-${FIRST_BLD}.txt
                  
                  write_log  ${NO_DIFF}  ${OUT}  "No changes: both builds use revision ${REV_1ST}"
                else
                  echo    git log --max-count=128 --name-status ${RANGE}
                  echo    git log ${RANGE}
                  echo    ----------------------------------------------------------
                  MSG=`git log --max-count=128 "${GITLOG}" --name-status ${RANGE}`  ; STATUS=$?
                  
                  if [[ $STATUS > 0 ]]
                      then
                      THIS_FAIL=1
                      OUT=${COMP}-GIT-ERROR.txt
                      write_log   ${ERRRORS}  ${OUT}  "GIT ERROR: ${MSG}"
                  else
                      echo logged changes: ${COMP}${BRANCH}
                      echo in:             ${OUT}
                      write_log   ${CHANGES}  ${OUT}  "${MSG}"
                  fi
              fi
          fi
      fi
      popd           > /dev/null
  fi
    
  if [[ ${THIS_FAIL} > 0 ]] ; then let FAILS++ ; fi
    
  sleep 10
done

if [[ ${FAILS} > 0 ]] ; then echo ${FAILS} tests FAILED
else
    echo All Tests Passed
fi
exit  ${FAILS}
__End__

