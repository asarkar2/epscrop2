#!/usr/bin/perl

use warnings ;
use strict ;
use File::Basename ;
use File::Which ;
use File::Copy ;

our($scriptname);
$scriptname = basename($0) ;
my $author = 'Anjishnu Sarkar' ;
my $version = "0.1" ;

my $gs = 'gs' ;
   $gs = "gswin32c" if $^O eq 'MSWin32'; 
my $epstopdf = 'epstopdf' ;
my $pdftops = 'pdftops' ;

my @requirements = ($epstopdf, $pdftops, $gs) ;
my $user_margins ;
my ($ineps, $outeps) ;
my $rtn ;
my $verbose = 'FALSE' ;

# Helptext
sub helptext{

    my ($sname, $au, $ver, $vrbs) = @_ ;

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
    "-v|--verbose   Be verbose. Default: $vrbs\n",
    "-q|--quiet     Default.\n",    
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

# Add margin
sub add_margin{
    
    my ($ghost, $ineps, $outeps, $usr_mrgns, $vrbs) = @_ ;
    &checksoftwares($ghost) ;
    
    my $bbname = '%%BoundingBox:' ;
    my $hiresbbname = '%%HiResBoundingBox:' ;
    my ($llx, $lly, $urx, $ury) ;

    my @gsopts = ("-dNOPAUSE", "-dBATCH", "-q", "-sDEVICE=bbox") ;
    my ($mllx,$mlly,$murx,$mury) = (0, 0, 0, 0);

    ## Margins: Taken from the script pdfcrop by Heiko Oberdiek and modified.
    if ($usr_mrgns) {
        if ($usr_mrgns =~ 
          /^\s*([\-\.\d]+)\s+([\-\.\d]+)\s+([\-\.\d]+)\s+([\-\.\d]+)\s*$/) {
        ## If four margins are supplied
            ($mllx, $mlly, $murx, $mury) = ($1, $2, $3, $4) ;
        } elsif ($usr_mrgns =~ /^\s*([\-\.\d]+)\s+([\-\.\d]+)\s*$/) { 
        ## If only two margins are supplied then $murx and $mury are 
        ## same as $mllx and $mlly respectively.
            ($mllx, $mlly, $murx, $mury) = ($1, $2, $1, $2) ;
        } elsif ($usr_mrgns =~ /^\s*([\-\.\d]+)\s*$/) { 
        ## If only one margin is supplied then all the margins are the same.
            ($mllx, $mlly, $murx, $mury) = ($1, $1, $1, $1) ;
        } else {
            die("Couldn't parse the option -m|--margins.\n") ;
        }
    }

    # Run gs to find the bounding box
    my @cmd_result = qx($ghost @gsopts $ineps 2>&1) ;

    my @bbox = grep(/$bbname/,@cmd_result);
    $bbox[0] =~ s/$bbname *// ;

    # Grab the bounding box
    if ( $bbox[0] =~ /^\s*([\-\.\d]+)\s+([\-\.\d]+)\s+([\-\.\d]+)\s+([\-\.\d]+)\s*$/){
        ($llx, $lly, $urx, $ury) = ($1, $2, $3, $4) ;
    } else {
        die("Couldn't parse the bounding box. Aborting.\n") ;
    }

    # Add the margins
    my $nllx = $llx - $mllx ;
    my $nlly = $lly - $mlly ;
    my $nurx = $urx + $murx ;
    my $nury = $ury + $mury ;

    # Get the directory name and extension of the input file.
    my (undef,$dirname,undef) = fileparse($ineps,'.eps') ;
    my $tmpfilepath = $dirname . int(rand(10000)) . '.eps' ;
    
    ## Open files for reading and writing
    open(EPSFILE,"<$ineps") or die "$!" ;
    open(TMPFILE,">$tmpfilepath") or die "$!" ;

    ## Change the bounding box
    while (<EPSFILE>) {
        if (/$bbname/) {

            s/$bbname *// ;
            if ($vrbs eq 'TRUE') {            
                print "Old Bounding box: $_" ;
                print "New Bounding box: $nllx, $nlly, $nurx, $nury\n" ;
            }
            print TMPFILE "$bbname $nllx $nlly $nurx $nury\n" ;

        } elsif (/$hiresbbname/) {
#         print "Omitting Hi resolution\n" ;
            next ;

        } else {
            print TMPFILE $_ ;

        }
    }

    close(TMPFILE) or die "$!" ;
    close(EPSFILE) or die "$!" ;

    ## Rename tmpfile to outepsfile 
    move($tmpfilepath,$outeps) ;

}

&checksoftwares($epstopdf,$pdftops) ;

## Parse command line arguments
while ( $_ = $ARGV[0] ){
    if ( (/^-h$/) || (/^--help$/)) {
        &helptext($scriptname, $author, $version, $verbose);

    } elsif (/\.eps$/)  {
        chomp ;
        $ineps = $_ ;

    } elsif ( (/^-m$/) || (/^--margins$/) ) {
        $user_margins = $ARGV[1] ;
        shift  ;

    } elsif ( (/^-o$/) || (/^--output$/) ) {
        $outeps = $ARGV[1] ;
        shift ;

    } elsif ( (/^-v$/) || (/^--verbose$/) ) {
        $verbose = 'TRUE' ;

    } elsif ( (/^-q$/) || (/^--quiet$/) ) {
        $verbose = 'FALSE' ;

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
my $tmpfilename = int(rand(10000)) ;
my $tmppdf = $dirname . $tmpfilename . '.pdf' ;
my $tmpeps = $dirname . $tmpfilename . '.eps' ;

# Convert to pdf
$rtn = system("$epstopdf $ineps $tmppdf") ;
die("Problem in running $epstopdf on $ineps") if ($rtn !=0 ) ; 

# Convert back to eps
$rtn = system("$pdftops -level3 -eps $tmppdf $tmpeps") ;
die("Problem in running $pdftops on $tmppdf.\n") if ($rtn != 0) ;

# If user margin is defined
if (defined($user_margins)){
    &add_margin($gs,$tmpeps,$outeps,$user_margins,$verbose) ;
} else {
    move($tmpeps, $outeps) ;
}

unlink($tmppdf) ;
unlink($tmpeps) ;
