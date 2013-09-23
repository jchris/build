#!/bin/perl
# 
############ 
#use strict;
use warnings;

package buildbotReports;

use Exporter qw(import);
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw( last_done_build last_good_build is_running sanity_url );

our %EXPORT_TAGS = ( DEFAULT => [qw( &last_done_build &last_good_build &is_running  &sanity_url )] );

my $DEBUG = 0;   # FALSE


############ 

use buildbotQuery   qw(:HTML :JSON );
use buildbotMapping qw(:DEFAULT);

use JSON;
my $json = JSON->new;

my $installed_URL='http://10.3.2.199';
my $run_icon  = '<IMG SRC="' .$installed_URL. '/running_20.gif" ALT="running..." HSPACE="50" ALIGN="TOP">';
my $done_icon = '&nbsp;';

my ($builder, $branch);

############                        is_running ( 0=no | 1=yes )
#          
#                                   returns icon indicating that latest build is not completed
#                                   
#                                   usually called with buildbotQuery::is_good_build()
sub is_running
    {
    my ($status) = @_;
    
    if ($status == 1 )  { if ($DEBUG) { print STDERR "...it's running...\n"; }  return( $run_icon);  }
    else                { if ($DEBUG) { print STDERR "....NOT RUNNING...\n"; }  return( $done_icon); }
    }


############                        last_done_build ( builder, branch, jenkins_index )
#          
#                                   returns ( status, iteration, build_num, build_date )
#                                   
#                                     where   status = buildbotQuery::is_good_build()
sub last_done_build
    {
    ($builder, $branch, $index) = @_;
    my ($bldnum, $next_bldnum, $result, $isgood, $rev_numb, $bld_date);
   
    if ($DEBUG)  { print STDERR 'DEBUG: running buildbotQuery::get_json('.$builder.', '.$index.")\n";    }
    my $all_builds = buildbotQuery::get_json($builder, $index);
    if (! ref $all_builds)
        {
        if ($DEBUG)  { print STDERR 'DEBUG: is not a reference, is code $all_builds\n'; }
        die "not JSON: $all_builds\n";
        }
    my $len = scalar keys %$all_builds;
    if ($DEBUG)  { print STDERR "\nDEBUG: all we got back was $all_builds\tlength:  $len\n"; }
    
    foreach my $KEY (keys %$all_builds)
        {
        if ($DEBUG)  { print STDERR ".";  }
        my $VAL = $$all_build{$KEY};
        if (! defined $VAL)  { $$all_build{$KEY}="null" }
        }
        if ($DEBUG)  { print STDERR "\n"; }
    
    if ($len < 1 )
        {                   if ($DEBUG)  { print STDERR "DEBUG: no builds yet!\n"; }
        $bldnum     = -1;
        $isgood     = 0;
        $rev_numb   = 0;
        $bld_date   = 'no build yet';
        }
    else
        {
        $bldnum     = (reverse sort { 0+$a <=> 0+$b } keys %$all_builds)[0];     if ($DEBUG)  { print STDERR "... getting results of build: $bldnum\n"; }
        $result     = buildbotQuery::get_json($builder, $index, '/'.$bldnum);    if ($DEBUG)  { print STDERR "... getting status of build:  $bldnum\n"; }
        
        $isgood     = buildbotQuery::is_good_build($result);                     if ($DEBUG)  { print STDERR "... getting build revision:   $bldnum\n"; }
        $rev_numb   = $branch .'-'. buildbotQuery::get_build_revision($result);  if ($DEBUG)  { print STDERR "... getting date of build:    $bldnum\n"; }
        $bld_date   = buildbotQuery::get_build_date($result);
        }
    
    my $is_running  = 0;
    
    $next_bldnum    = 1+ $bldnum;                                                if ($DEBUG)  { print STDERR "....is $next_bldnum running?\n";          }
    my $next_build  = buildbotQuery::get_json($builder, $index, '/'.$next_bldnum);
    if ( buildbotQuery::is_running_build( $next_build) ) { $is_running = 1;  if ($DEBUG)  { print STDERR "$bldnum is still running\n"; } }
    

    if ($DEBUG)  { print STDERR "... bld_date is $bld_date...\n"; }
    if ($DEBUG)  { print STDERR "... rev_numb is $rev_numb...\n"; }
    
    return( buildbotQuery::is_good_build($result), $bldnum, $rev_numb, $bld_date, $is_running);
    }



############                        last_good_build ( builder, branch, jenkins_index )
#          
#                                   returns ( iteration, build_num, build_date )
#                                        or ( 0 )  if no good build
sub last_good_build
    {
    ($builder, $branch, $index) = @_;
    my ($bldnum, $last_bldnum, $next_bldnum, $result);
    
    my $all_builds = buildbotQuery::get_json($builder, $index);
    
    foreach my $KEY (keys %$all_builds)
        {
        my $VAL = $$all_build{$KEY};
        if (! defined $VAL)  { $$all_build{$KEY}="null" }
        }
    my $is_running  = 0;
    $last_bldnum    = (reverse sort { 0+$a <=> 0+$b } keys %$all_builds)[0];
    $next_bldnum    = 1+ $last_bldnum;                                       if ($DEBUG)  {  print STDERR "......is $next_bldnum running?\n";}
    my $next_build  = buildbotQuery::get_json($builder, $index, '/'.$next_bldnum);
    if ( buildbotQuery::is_running_build( $next_build) ) { $is_running = 1;  if ($DEBUG)  { print STDERR "$next_bldnum is still running.\n"; } }
    
    foreach my $KEY (reverse sort { 0+$a <=> 0+$b } keys %$all_builds)
        {
        $bldnum = $KEY;                                                      if ($DEBUG)  { print STDERR "....$bldnum   $$all_build{$bldnum}\n"; }
        $result = buildbotQuery::get_json($builder, $index, '/'.$bldnum);    if ($DEBUG)  { print STDERR "....is $bldnum running?\n"; }
        if ( buildbotQuery::is_running_build( $result) )
            {
            if ($DEBUG)  { print STDERR "$bldnum is still running\n"; }
            $is_running = 1;
            }
        elsif ( ! buildbotQuery::is_good_build( $result) )
            {
            if ($DEBUG)  { print STDERR "$bldnum did FAIL\n"; }
            }
        else
            { last; }
        }
    my $rev_numb = $branch .'-'. buildbotQuery::get_build_revision($result);
    my $bld_date = buildbotQuery::get_build_date($result);
    
  # print STDERR "... rev_numb is $rev_numb...\n";
  # print STDERR "... bld_date is $bld_date...\n";
    
    if  ( buildbotQuery::is_good_build( $result) )
        {
        
        print STDERR "GOOD: $bldnum\n"; 
        return($bldnum, $rev_numb, $bld_date, $is_running);
        }
    else
        {
        print STDERR "FAIL: $bldnum\n"; 
        return(0);
        }
    }

############                        sanity_url ( builder, build_number, url_root_index )
#          
#                                   returns ( test job url, boolean did test pass, test job number )
#                                        or ( -1, 0, 0 )  if no test was triggered,
#                                                          or cannot get info
#                                        or (  0, 0, 0 )  if no test attempted
sub sanity_url
    {
    my ($builder, $bld_num, $bindex) = @_;
    my ($tindex, $test_url_root);
    my  $url_rex = '[htps]*://([a-zA-Z0-9.:_-]*)/+job/+([a-zA-Z0-9_-]*)';
    if ($DEBUG)     { print STDERR "============================\nentering sanity_url($builder, $bld_num, $bindex)\n"; }
     
    my ($test_url, $bld_revision) = buildbotQuery::trigger_jenkins_url($builder, $bld_num, $bindex );
    if ($test_url =~ /^[0-9-]*$/)
        {
        if ($test_url == -1)
            {
            if ($DEBUG)  { print STDERR "FAILED to start test\n"; }
            return(-1, 0, 0);
            }
        if ($DEBUG)  { print STDERR "I guess we found a test\n"; }
        
        if ($test_url <= 0)
            {
            my  $errcode = $test_url;
            my  $status  = $bld_revision;
            if ($status  == 0)
                {
            if ($DEBUG) { print STDERR "no jenkins STEP, or no test attempted\n"; }
                }
            if ($DEBUG)     { print STDERR "HTTP code: $status\n"; }
            
            return($errcode, $status, 0);
        }   }
    
    if ($DEBUG)     { print STDERR "returned: ($test_url, $bld_revision)\n";             }
    
    if ($test_url =~ $url_rex)
        {
        $test_url_root = $1;
        $test_job_name = $2;
        if ($DEBUG)  { print STDERR "extracted (url domain, test job) = ( $test_url_root , $test_job_name)\n     from $test_url\n"; }
        }
    else
        {
        if ($DEBUG)  { print STDERR "$test_url is NOT a jenkins URL\n\n"; }
        return(0, 0, 0);
        }
    ($test_url, $tindex) = buildbotQuery::get_URL_root($test_url_root);
    if ($DEBUG)     { print STDERR "returned: ($test_url, $tindex)\n";                }
    $test_url = $test_url.'/job/'.$test_job_name;
    
    my ($did_pass, $test_job_url, $test_job_num) = buildbotQuery::test_job_results($test_url, $bld_revision);
                      if ($DEBUG)  { print STDERR "test_job_results are: ($did_pass, $test_job_url, $test_job_num)\n"; }

#                                   returns:  ( test passed ?, URL of test job,  number of test job)
#                                   on error: ( ZERO,          error CODE,       error MESSAGE)

    if ($test_job_url =~ /^[0-9-]*$/)  { return(0,0,0); }
    if ($did_pass)  { if ($DEBUG)  { print STDERR "it passed\n";  }                   }
                      if ($DEBUG)  { print STDERR "It was $test_job_num that tested $bld_revision\n";   }
    return($test_job_url, $did_pass, $test_job_num);
    }

1;
__END__

