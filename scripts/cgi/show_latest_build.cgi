#!/usr/bin/perl

# queries buildbot JSON api to find latest good build of a specific builder.
#  
#  Call with these parameters:
#  
#  BUILDER         e.g. cs-win2008-x64-20-builder-202
#  BRANCH          e.g. 2.0.2.  NOTE: must match!
#  
use warnings;
#use strict;
$|++;

my $DEBUG = 0;

use File::Basename;
use Cwd qw(abs_path);
BEGIN
    {
    $THIS_DIR = dirname( abs_path($0));    unshift( @INC, $THIS_DIR );
    }

use buildbotQuery   qw(:HTML :JSON );
use buildbotMapping qw(:DEFAULT);
use buildbotReports qw(:DEFAULT);

use CGI qw(:standard);
my  $query = new CGI;

my $buildbot_url_index = 'hq';
my $buildbot_URL       = 'http://builds.hq.northscale.net:8010';

my $delay = 1 + int rand(3.3);    sleep $delay;

my ($good_color, $warn_color, $err_color, $note_color) = ('#CCFFDD', '#FFFFCC', '#FFAAAA', '#CCFFFF');

my $timestamp = "";
sub get_timestamp
    {
    my $timestamp;
    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    $month =    1 + $month;
    $year  = 1900 + $yearOffset;
    $timestamp = "page generated $hour:$minute:$second  on $year-$month-$dayOfMonth";
    }

sub print_HTML_Page
    {
    my ($frag_left, $frag_right, $page_title, $color) = @_;
    
    print $query->header;
    print $query->start_html( -title   => $page_title,
                              -BGCOLOR => $color,
                            );
    print "\n".'<div style="overflow-x: hidden">'."\n"
         .'<table border="0" cellpadding="0" cellspacing="0"><tr>'."\n".'<td valign="TOP">'.$frag_left.'</td><td valign="TOP">'.$frag_right.'</td></tr>'."\n".'</table>'
         .'</div>'."\n";
    print $query->end_html;
    }
my $installed_URL='http://10.3.2.199/cgi/show_latest_build.cgi';

my $usage = "ERROR: must specify  EITHER both 'builder' and 'branch' params\n"
           ."                         OR all of 'platform', 'bits', 'branch'\n\n"
           ."<PRE>"
           ."For example:\n\n"
           ."    $installed_URL?builder=cs-win2008-x64-20-builder-202&branch=2.0.2\n\n"
           ."    $installed_URL?platform=windows&bits=64&branch=2.0.2\n\n"
           ."</PRE><BR>"
           ."\n"
           ."For toy builders, use 'toy', 'platform', 'bits', like:\n\n"
           ."<PRE>"
           ."    $installed_URL?toy=plabee-211-identical&platform=centos&bits=64\n\n"
           ."</PRE><BR>"
           ."\n";

my ($builder, $branch, $platform, $toy_name);

if ( $query->param('builder') && $query->param('branch') )
    {
    $builder = $query->param('builder');
    $branch  = $query->param('branch');
    print STDERR "\nready to start with ($builder, $branch)\n";
    }
elsif( ($query->param('platform')) && ($query->param('bits')) && ($query->param('branch')) )
    {
    $branch  = $query->param('branch');
    $builder = buildbotMapping::get_builder( $query->param('platform'), $query->param('bits'), $branch );
    print STDERR "\nready to start with ($builder)\n";
    }
elsif( ($query->param('toy')) &&($query->param('platform')) &&  ($query->param('bits')) )    # TOY
    {
    $toy_name = $query->param('toy');
    $platform = $query->param('platform');
    $bits     = $query->param('bits');
    
    $builder = buildbotMapping::get_toy_builder($toy_name, $platform, $bits);
    print STDERR "\nready to start with toy ($builder)\n";
    }
else
    {
    print_HTML_Page( buildbotQuery::html_ERROR_msg($usage), '&nbsp;', $builder, $err_color );
    exit;
    }


#### S T A R T  H E R E 

if ($DEBUG)  { print STDERR "================================\ngetting last done build of ($builder, $branch, $buildbot_url_index))\n"; }

my ($bldstatus, $bldnum, $rev_numb, $bld_date, $is_running) = buildbotReports::last_done_build($builder, $branch, $buildbot_url_index);

if ($DEBUG)  { print STDERR "================================\naccording to last_done_build, is_running = $is_running\n"; }

if ($bldnum < 0)
    {
    print_HTML_Page( 'no build yet',
                     buildbotReports::is_running($is_running),
                     $builder,
                     $note_color );
    }
elsif ($bldstatus)
    {
    my $running = buildbotReports::is_running($is_running);
    
    my ($test_job_url, $did_pass, $test_job_num) = buildbotReports::sanity_url($builder, $bldnum, $buildbot_url_index);

    my $made_color;
    
    if ($DEBUG)  { print STDERR "test_job_url is $test_job_url\ndid_pass is $did_pass"; }
    if ($test_job_url =~ /^[0-9-]$/)
        {
        if ($test_job_url <= 0)
            {
            $made_color   = $warn_color;    print STDERR "did not pass a sanity test\n";
            $running     .='&nbsp;&nbsp;&nbsp;NO TEST';
            }
        }
    elsif ($did_pass)
        {
        $made_color   = $good_color;
        $running     .= '&nbsp;&nbsp;passed:&nbsp;<a href="'.$test_job_url.'">'.$test_job_num.'</a>';
        }
    else{
        $made_color   = $warn_color;    print STDERR "did not pass a sanity test\n";
        if ($test_job_num > 0)
            {
            $running .= $running.'&nbsp;&nbsp;FAILED:&nbsp;<a href="'.$test_job_url.'">'.$test_job_num.'</a>';
            }
        else
            {
            $running     .='&nbsp;&nbsp;&nbsp;NO TEST';
            }
        }
    
    print_HTML_Page( buildbotQuery::html_OK_link( $builder, $bldnum, $rev_numb, $bld_date, $buildbot_url_index),
                     $running,
                     $builder,
                     $made_color );
    
    print STDERR "GOOD: $bldnum\n"; 
    }
else
    {
    print STDERR "FAIL: $bldnum\n"; 
   
    my $background; 
    if ( $is_running == 1 )
        {
        $bldnum += 1;
        $background = $warn_color;
        }
    else
        {
        $background = $err_color;
        }
    print_HTML_Page( buildbotReports::is_running($is_running),
                     buildbotQuery::html_FAIL_link( $builder, $bldnum, $buildbot_url_index),
                     $builder,
                     $background );
    }


# print "\n---------------------------\n";
__END__

