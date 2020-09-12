#!/usr/bin/perl

# Thanks to use answer (Method B) to use pdfcrop instead of gs to get the 
# correct bounding box 
# https://tex.stackexchange.com/a/171460/182471

use warnings ;
use strict ;
use File::Basename ;
use File::Which ;
use File::Spec ;

our($scriptname);
$scriptname = basename($0) ;
my $author = 'Anjishnu Sarkar' ;
my $version = "0.2" ;

my $epstopdf = 'epstopdf' ;
my $pdfcrop = 'pdfcrop' ;
my $pdftops = 'pdftops' ;

my @requirements = ($epstopdf, $pdfcrop, $pdftops) ;
my $margins = 0 ;
my ($ineps, $outeps) ;
my $rtn ;

my $devnull = File::Spec->devnull();

# Helptext
sub helptext{

    my ($sname, $au, $ver) = @_ ;

    print 
    "Crops eps file with suitable margins.\n", 
    "Usage: $sname input.eps [options] [-o output.eps]\n",
    "Author: $au\n",
    "Version: $ver\n",
    "\n",
    "Options:\n",
    "-h|--help      Show this help and exit.\n",
    "-m|--margins   Specify margins. The margins correspond to lower left\n",
    "               x (mllx), lower left y (mlly), upper right x (murx)\n",
    "               and upper right y (mury). If only two numbers are\n",
    "               specified, then these are used for both (mllx, mlly)\n",
    "               and (murx, mury). If only one number is specified, it is\n",
    "               used for all margins.\n",
    ;
    exit 0 ;
}

## Check the required softwares
sub checksoftwares{
    my @require = @_ ;
    ## Check for requirements
    foreach my $software (@require){
        die("\"$software\" not found.\n") if (!defined(which($software))) ;
    }    
}

&checksoftwares($epstopdf,$pdftops) ;

## Parse command line arguments
while ( $_ = $ARGV[0] ){
    if ( (/^-h$/) || (/^--help$/)) {
        &helptext($scriptname, $author, $version);

    } elsif (/\.eps$/)  {
        chomp ;
        $ineps = $_ ;

    } elsif ( (/^-m$/) || (/^--margins$/) ) {
        $margins = $ARGV[1] ;
        shift  ;

    } elsif ( (/^-o$/) || (/^--output$/) ) {
        $outeps = $ARGV[1] ;
        shift ;

    } else {
        die("Unspecified option \"$_\".\n");

    }
    shift ;
}

## Check for existence of the input eps file
if ( $ineps ) {
    die("Specified epsfile \"$ineps\" not found.","") 
        if (! -e $ineps) ; 
} else {
    die("No input file supplied. Aborting.\n") ;
}
 
# If output eps file is not mentioned, then it is assumed to be same
# as input eps file.
if (! $outeps) {
    $outeps = $ineps ;
} else {
    # If output file is supplied, then check the extension of the output file.
    my (undef, undef, $ext) = fileparse($outeps, qr"\..[^.]*$") ;
    die("Output file is not an '.eps' file. Aborting.\n") if ($ext ne '.eps') ;
}

my (undef,$dirname,undef) = fileparse($ineps,'.eps') ;
my $tmppdf = $dirname . int(rand(10000)) . '.pdf' ;

# Convert to pdf
$rtn = system("$epstopdf $ineps $tmppdf") ;
die("Problem in running $epstopdf on $ineps") if ($rtn !=0 ) ; 

# Crop the pdf file using pdfcrop
$rtn = system("$pdfcrop --margins '$margins' $tmppdf $tmppdf > $devnull") ;
die("Problem in running $pdfcrop on temporary pdf file") if ($rtn !=0 ) ; 

# Convert back to eps
$rtn = system("$pdftops -level3 -eps $tmppdf $outeps") ;
die("Problem in running $pdftops on $tmppdf.\n") if ($rtn != 0) ;

# Delete the temporary pdf file
unlink($tmppdf) ;
