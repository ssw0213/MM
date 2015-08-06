# MM
Putting VistA in West Virginia

  My email: swatson@mmwv.co

  These are routines to clean up Electronic Data Interchange (EDI) 
  medical billing claim files.

  The "clean" file is a shell script. It needs to be executable -
    chmod +x clean
  and placed in your path - on DEV it is
    mv clean ~/.local/bin
  All it does is call the mumps routine ZSSWCLMS.m
  It accepts one option:  -v or --version, prints version and quits.

  Be sure GT.M mumps is installed, and place the ZSSWCLMS.m routine
  in its PATH - on DEV it is:
    echo $gtmroutines
    mv ZSSWCLMS.m ~/p

  To run it, place all your EDI files in a directory at
    /home/opus/share
  Then issue the command "clean"
    clean

  The results will be found in ~/cleaning, with a subdirectory for each 
  day's files. In that directory will be "in" containing your original
  files, and "out" containing files ending in ".clean", plus a log file.
  Read the log file to see what was done to the files and be sure it is
  correct.
  
