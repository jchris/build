#!/bin/perl
# 
############ 

package buildbotQuery;

use strict;

use Exporter qw(import);
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw( get_URL_root html_builder_link html_OK html_ERROR_msg html_OK_link html_FAIL_link
                       get_json get_build_revision get_build_date is_running_build is_good_build );

our %EXPORT_TAGS = ( HTML  => [qw( &get_URL_root &html_builder_link &html_OK &html_ERROR_msg &html_OK_link &html_FAIL_link )],
                     JSON  => [qw( &get_json  &get_build_revision  &get_build_date  &is_running_build  &is_good_build      )] );

############ 

use CGI qw(header -no_debug);

use JSON;
my $json = JSON->new;

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

my $USERID='buildbot';
my $PASSWD='buildbot';
my %URL_ROOT = ( "hq"  => 'http://builds.hq.northscale.net:8010',
                 "qa"  => 'http://qa.hq.northscale.net:8080',
                 "qe"  => 'http://qa.sc.couchbase.com',
                 "bnr" => 'http://factory:8080',
                 "mac" => 'http://macbuild.local:8080',
                 "sdk" => 'http://sdkbuilds.couchbase.com',
               );

my $DEBUG = 0;


############ HTML


############                        get_URL_root ( index /OR/ value_regex )
#          
#                                   returns: URL_ROOT  /OR/ URL_ROOT and proper index
sub get_URL_root
    {
    my ($index) = @_;
    
    if ( defined($URL_ROOT{$index}) )     { return $URL_ROOT{$index}; }
    else                                  { if ($DEBUG) { print  STDERR "no such jenkins server [ ".$index." ]\n"; } }
    
    my $val_rex = $index;    if ($DEBUG)  { print  STDERR "...so '$val_rex' is a URL to match to values\n"; }
    for my $key ( keys(%URL_ROOT) )
        {
        if ($DEBUG)  { print STDERR "...$key...\n"; }
        if ($URL_ROOT{$key} =~ $val_rex)  { return($URL_ROOT{$key}, $key); }
        }
    return(0);
    }


############                        html_builder_link ( <builder>, <jenkins_index> )
#          
#                                   returns HTML of link to good build results
sub html_builder_link
    {
    my ($bder, $index) = @_;
    my $HTML = '<a href="'. $URL_ROOT{$index} .'/builders/'. $bder .'" target="_blank">'. $bder .'</a>';
    
    return($HTML);
    }

############                        html_OK
#          
#                                   returns HTML of greeen OK
sub html_OK
    {
    return '<font color="green">OK</font>';
    }

############                        html_ERROR_msg
#          
#                                   returns HTML of red ERROR message
sub html_ERROR_msg
    {
    my ($msg) = @_;
    
    return '<font color="red">'. $msg .'</font>';
    }


############                        html_OK_link ( <builder>, <build_num>, <revision>, <date>, <jenkins_index> )
#          
#                                   returns HTML of link to good build results
sub html_OK_link
    {
    my ($bder, $bnum, $rev, $date, $index) = @_;
    
    my $HTML='<a href="'. $URL_ROOT{$index} .'/builders/'. $bder .'/builds/'. $bnum .'" target="_blank">'. "$rev ($date)" .'</a>';
    return($HTML);
    }

############                        html_FAIL_link ( <builder>, <build_num>, <is_build_running>, <jenkins_index> )
#          
#                                   HTML of link to FAILED build results
sub html_FAIL_link
    {
    my ($bder, $bnum, $is_running, $index) = @_;
    
    my $HTML = '<font color="red">FAIL</font><BR>'
              .'<PRE>...tail of log of last build step...</PRE>'
              .'<a href="'.$URL_ROOT{$index}.'/builders/'.$bder.'/builds/'.$bnum.'" target="_blank">build logs</a>';
    
    return($HTML);
    }

###########  JSON


############                        get_json ( <builder>, <jenkins_index>, <optional_URL_extension> )
#          
sub get_json
    {
    my ($bldr, $index, $optpath) = @_;
    my $returnref;
    if ($DEBUG)  { print STDERR "called GET_JSON($bldr, $index, $optpath)\n"; }
    
    my $request  = $URL_ROOT{$index} .'/json/builders/'. $bldr .'/builds';
    if (defined $optpath)  { $request .= $optpath;  }
    if ($DEBUG)  { print STDERR "\nrequest: $request\n\n"; }
    my $response = $ua->get($request);
    if ($DEBUG)  { print STDERR "respons: $response\n\n";  }
    
    if ($response->is_success)
        {
        $returnref = $json->decode($response->decoded_content);
        return $returnref;
        }
    else
       {
       if ($response->status_line =~ '404')  { return(0); }
       die $response->status_line;
    }  }

sub get_build_revision
    {
    my ($jsonref) = @_;
    
    if ( defined( $$jsonref{properties} ))
        {
        if ($DEBUG)  { print STDERR "(good ref.) $$jsonref{properties}\n"; }
        if ( defined( $$jsonref{properties}))
            {
            my $lol = $$jsonref{properties};
            if ($DEBUG)  { print STDERR "DEBUG: list-of-lists  is $lol\n"; }
            for my $lil (@$lol)
                {
                if ($DEBUG)  { print STDERR "DEBUG: little in list is $lil\n"; }
                if ( $$lil[0] eq 'git_describe' )
                    {
                    if ($DEBUG)     { print STDERR "DEBUG: key is $$lil[0]\n"; }
                    if ($DEBUG)     { print STDERR "DEBUG: 1st is $$lil[1]\n"; }
                    if ($DEBUG)     { print STDERR "DEBUG: 2nd is $$lil[2]\n"; }
                    return $$lil[1];
                    }
                else { if ($DEBUG)  { print STDERR "DEBUG: key is $$lil[0]\n"; }}
                }
        }   }
    die "Bad Reference\n";
    }

sub get_build_date
    {
    my ($jsonref) = @_;
    
    if ( defined( $$jsonref{times} ))
        {
        my $times = $$jsonref{times};
        my ($start, $end) = ( $$times[0], $$times[1] );
        
        if ($DEBUG)  { print STDERR "DEBUG: start is $start\n"; }
        if ($DEBUG)  { print STDERR "DEBUG: end   is $end  \n"; }
        my $end_time = int(0+ $end );
        if ($DEBUG)  { print STDERR "DEBUG: found end_time: $end_time\n"; }
        my ($second, $minute, $hour, $dayOfMonth, $month, $year, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime(int($end_time));
        $year  += 1900;
        $month += 1;
     #  return $year .'-'. $month .'-'. $dayOfMonth;
        return $month .'/'. $dayOfMonth .'/'. $year;
        }
    die "Bad Reference\n";
    }


############                        is_running_build ( <json_hash_ref> )
#          
#                                   returns TRUE if "results" value is null
sub is_running_build
    {
    my ($jsonref) = @_;    return ($jsonref) if ($jsonref==0);
    
    if ( defined($$jsonref{results}) && $DEBUG )  { print STDERR "DEBUG: results is: $$jsonref{results}\n"; }
    if ($DEBUG)  { print STDERR "DEBUG: called is_running_build($jsonref)\n"; }
    return (! defined($$jsonref{results}) );
    }


############                        is_good_build ( <json_hash_ref> )
#          
#                                   returns TRUE if "results" value is 0
sub is_good_build
    {
    my ($jsonref) = @_;
    if ( defined($$jsonref{results}) )
        {
        if ($DEBUG)  { print STDERR "DEBUG: results is:$$jsonref{results}:\n"; 
        if     ($$jsonref{results} == 0 ) { print 'TRUE '; }  else { print 'False '; }
                     }
        return ($$jsonref{results} == 0 );
        }
    print STDERR "ERROR: bad ref\n\n";
    return(0 == 1);
    }

############                        trigger_jenkins_url ( <builder>, <bld_num>, <jenkins_index> )
#          
#                                   returns URL of test job and build number, or "" if none found
sub trigger_jenkins_url
    {
    my ($builder, $bld_num, $index) = @_;
    my $url_rex = 'curl &#39;(.*)&#39;';
    
    my $request = $URL_ROOT{$index}.'/builders/'.$builder.'/builds/'.$bld_num.'/steps/trigger%20jenkins/logs/stdio';
    if ($DEBUG)  { print STDERR "request: $request\n\n";  }
    
    my $response = $ua->get($request);
    if ($DEBUG)  { print STDERR "respons: $response\n\n";  }

    if ($response->is_success)
        {
        if ($DEBUG)  { print STDERR "FOUND IT\n"; }
        my $content = $response->decoded_content;
        if ( $content =~ $url_rex )
            {
            my $curlurl = $1;
            my ($jenkins_url, $version_num) = ("", "");
            
            if ($DEBUG)  { print STDERR "IT MATCHES\n"; }
            if ($curlurl =~ '(.*)/buildWithParameters'         )  { $jenkins_url = $1; }
            if ($curlurl =~ 'version_number=([0-9a-zA-Z._-]*)' )  { $version_num = $1; }
            return($jenkins_url, $version_num);
            }
        if ($DEBUG)  { print STDERR "cannot find curl request in:\n\n".$content."\n"; }
        return(0);
        }
    else
       {
       if ($response->status_line =~ '404')  { if ($DEBUG)  { print STDERR "NO RESONSE\n"; }  return(0); }
       if ($DEBUG)  { print STDERR "DEBUG: no response!  Got status line:\n\n".$response->status_line."\n"; }
       return($response->status_line);
    }  }
 
############                        test_job_results ( test_url , bld_revision )
#
#                                   returns: ( URL of test job, (True/False) whether test passed, number of test job)
#                                   if none: ( 
sub test_job_results
    {
    my ($test_url, $bld_revision) = @_;
    if ($DEBUG)  { print STDERR "============================\nDEBUG: entering test_job_results($test_url, $bld_revision)\n"; }

    my $request = $test_url.'/api/json/builds/';
    if ($DEBUG)  { print STDERR "request: $request\n\n";  }
    my $version;
    
    my $response = $ua->get($request);
    if ($DEBUG)  { print STDERR "respons: $response\n\n";  }

    if ($response->is_success)
        {
        my $jsonref       = $json->decode($response->decoded_content);
        my $results_array = $$jsonref{'builds'};
        my $len = $#$results_array;
        if ($len < 1)
            {
            if ($DEBUG)  { print STDERR "no test results for $test_url\n"; }
            return("","","");
            }
        else
            {
            my @results_numbers;
            my %param_ref;
            for my $item ( 0 .. $len)  { if ($DEBUG) { print STDERR "array[ $item ] is $$results_array[$item]\n"; }
                                                       push @results_numbers, $$results_array[$item]{'number'};
                                                     }
            for my $tnum ( (reverse sort @results_numbers ) )
                {
                $request  = $test_url.'/'.$tnum.'/api/json/builds/';
                if ($DEBUG)  { print STDERR "[ $tnum ]:: $request \n"; }
                $response = $ua->get($request);
                if ($response->is_success)
                    {
                    $jsonref = $json->decode($response->decoded_content);
                    if ( defined(  $$jsonref{'actions'} ))  #{'parameters'}{'version_number'} ))
                        {
                        if ( defined(  $$jsonref{'actions'}[0]{'parameters'} ))
                            {
                            my $param_array = $$jsonref{'actions'}[0]{'parameters'};
                            for my $item (0 .. $#$param_array)  { $param_ref{$$param_array[$item]{'name'}} = $$param_array[$item]{'value'};
                                                                  if ($DEBUG) { print STDERR "item $item has name  $$param_array[$item]{'name'}\n";  }
                                                                  if ($DEBUG) { print STDERR "item $item has value $$param_array[$item]{'value'}\n"; }
                                                                }
                            $version = $param_ref{'version_number'};
                            if ($version == $bld_revision)
                                {
                                if ($DEBUG) { print STDERR "item has version $version\n"; }
                                }
                            
                          # if ($DEBUG) { print STDERR "there are $#params params\n"; }
                          # for my $item (0 .. $#params)
                          #     {
                          #     if ($DEBUG) { print STDERR "param $item is $params[$item]\n"; }
                          #     if ( $params[$item]{'name'} == 'version_number' )  { $version = $params[$item]{'value'};
                          #                                                          if ($DEBUG) { print STDERR "item $item has version $version\n"; }
                          #                                                        }
                          #     else                                               { if ($DEBUG) { print STDERR "item $item has name $params[$item]{'name'}\n"; }}
                          #     }
                            my $did_pass = 0;
                            if ($$jsonref{"result"} == "SUCCESS")  { $did_pass = 1; }
                            if ($version == $bld_revision)  { return($did_pass, $test_url.'/'.$tnum, $tnum); }
                            }
                        }
                    }
                else
                    {
                    if ($response->status_line =~ '404')  { return(0); }
                    die $response->status_line;
                    }
                }
            }
        return("","","");
        }
    else
        {
        if ($response->status_line =~ '404')  { return(0); }
        if ($response->code        =~ /5*/ )  { return(0); }
        die $response->status_line;
    }   }


1;
__END__
