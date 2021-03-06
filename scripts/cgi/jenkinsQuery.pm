#!/bin/perl
# 
############ 

package jenkinsQuery;

use strict;

use Exporter qw(import);
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw( test_running_indicator response_code test_job_status get_json get_url_root html_OK_link );

our %EXPORT_TAGS = ( DEFAULT  => [qw( &test_running_indicator &response_code &test_job_status &get_json &get_url_root &html_OK_link )] );

############ 

use CGI qw(header -no_debug);

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

use JSON;
my $json = JSON->new;

#use XML::Parser;
#my $xml = new XML::Parser(Style => 'Tree');

my $USERID='buildbot';
my $PASSWD='buildbot';
my $URL_ROOT='http://factory.hq.couchbase.com:8080';

my $DEBUG = 0;

############                        get_url_root ( )
#          
#           
#
sub get_url_root
    {
    return($URL_ROOT);
    }
############                        html_OK_link ( <builder>, <job_number>, <build_num>, <job_date> )
#          
#                                   returns HTML of link to good build results
sub html_OK_link
    {
    my ($builder, $bnum, $rev, $date) = @_;
    
    my $HTML='<a href="'. $URL_ROOT .'/job/'. $builder .'/'. $bnum .'" target="_blank">'. "$rev".'&nbsp;'."($date)" .'</a>';
    return($HTML);
    }

############                        html_FAIL_link ( <builder>, <build_num>, <is_running>, <build_date> )
#          
#                                   HTML of link to FAILED build results
sub html_FAIL_link
    {
    my ($builder, $bnum, $is_running, $date) = @_;
    
    my $HTML = '<font color="red">FAIL</font>&nbsp;&nbsp;' ."($date)". '&nbsp;&nbsp;'
              .'<a href="'.$URL_ROOT.'/job/'.$builder.'/'.$bnum.'" target="_blank">build logs</a>';
    
    return($HTML);
    }

############                        get_json ( $builder  = "build_sync_gateway_$branch"; )
#          
#           
#
sub get_json
    {
    my ($bldr, $optpath) = @_;    
    my $returnref;
    
    my $request  = $URL_ROOT .'/job/'. $bldr .'/api/json';
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



############                        test_running_indicator ( <installed_URL>, <test job number>, <test_job_url> )
#          
#           
sub test_running_indicator
    {
    my ($installed_URL, $test_job_num, $test_job_url) = @_;
    my $run_icon  = 'test&nbsp;'.$test_job_num.'<IMG SRC="' .$installed_URL. '/running_20.gif" ALT="running..." HSPACE="50" ALIGN="TOP">';
    my $run_icon  = 'test&nbsp;<a href="'.$test_job_url.'">'.$test_job_num.'</a>&nbsp;running...';

    return $run_icon;
    }

############                        response_code ( <http response> )
#          
#          
#                                   returns ( http status code )
sub response_code
    {
    my ($resp) = @_;
    my  $stat  = $resp->status_line;
    my  $srex  = '^([0-9]{3})';
    if ($stat =~ $srex)
        {
        my $code = $1;
        if ($DEBUG)  { print STDERR "HTTP code from [ $stat ] = $code\n"; }
        return $code;
        }
    return(0);
    }



############                        test_job_status ( test_job_url, rev_num )
#          
#                                   returns ( test_job_num, job_status, test_running ),
#                                        or ( 0, 0 ),                                  if no matching test (e.g., not completed yet)
#                                        or ( 0, status_code)                          if http response not 200
sub test_job_status
    {
    my ($test_job_url, $rev_num) = @_;           if ($DEBUG)  { print STDERR "calling test_job_status( $test_job_url, $rev_num )\n";  }
    
    my ($test_job_num, $job_status, $test_running) = (0,0,0);
    
    my $request  = $test_job_url .'/api/json/builds/';
    my $response = $ua->get($request);
    my $code = response_code($response);         if ($DEBUG)  { print STDERR "response to $request\n         is $code\n"; }
    
    if (! $response->is_success)
        {
        return(0, $code);
        }
    my $content = $response->decoded_content;    if ($DEBUG)  { print STDERR "content:$content\n"; }
    my $jsonref = $json->decode($content);
    my $results_array = $$jsonref{'builds'};
    my $len = $#$results_array;
    if ($len < 1)
        {
        if ($DEBUG)  { print STDERR "no test results for $test_job_url\n"; }
        return(0,0);
        }
    my @results_numbers;
    my %param_ref;
    for my $item ( 0 .. $len)  { if ($DEBUG) { print STDERR "array[ $item ] is $$results_array[$item]\n"; }
                                               push @results_numbers, $$results_array[$item]{'number'};
                                             }
    for my $tnum ( (reverse sort @results_numbers ) )
        {
        $request  = $test_job_url.'/'.$tnum.'/api/json/builds/';
        if ($DEBUG)  { print STDERR "[ $tnum ]:: $request \n"; }
        $response = $ua->get($request);
        $code = response_code($response);    if ($DEBUG)  { print STDERR "response to $request\n         is $code\n"; }
        $response = $ua->get($request);
        if (! $response->is_success)
            {
            if ($DEBUG) { print STDERR "RESPONSE: $code\n          $response->status_line\n"; }
            return(0, $code);
            }
        $jsonref = $json->decode($response->decoded_content);
        if ( ! defined( $$jsonref{'actions'} ))
            {
            if ($DEBUG)  { print STDERR "no test results for $test_job_url\n"; }
            return(0,0);
            }
        
        if ( ! defined(  $$jsonref{'actions'}[0]{'parameters'} ))
            {
            if ($DEBUG)  { print STDERR "no test results for $test_job_url\n"; }
            return(0,0);
            }
         
        my $param_array = $$jsonref{'actions'}[0]{'parameters'};
        for my $item (0 .. $#$param_array)  { $param_ref{$$param_array[$item]{'name'}} = $$param_array[$item]{'value'};
                                              if ($DEBUG) { print STDERR "item $item has name  $$param_array[$item]{'name'}\n";  }
                                              if ($DEBUG) { print STDERR "item $item has value $$param_array[$item]{'value'}\n"; }
                                            }
        my $version = $param_ref{'version_number'};
        if ($version == $rev_num)
            {
            if ($DEBUG) { print STDERR "item has version $version\n"; }
            $test_job_num = $tnum;
            $test_running = $$jsonref{'building'};
            $job_status   = $$jsonref{'result'};
            last;
        }   }
    
    return ( $test_job_num, $job_status, $test_running );
    }

1;
__END__
