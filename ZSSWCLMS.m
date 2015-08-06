ZSSWCLM   ; Routine to remove REV*G5 and REV*G2 entries from EDI files
                ; SSW 3150527
          ; Place all files to be cleaned in directory /home/opus/share/
          ; FP() is path to input file. Output goes to 
	  ; Output will be found in ~/cleaning/claims.<date>/out/FN.clean
	Q
START	N NREV S NREV="v1.1"  ; Revision number of this routine
	N V S V=$ZCMDLINE
	I $L(V) D
	. ; If this is a version request, print version and quit.
	.I $G(V)?1(1"-v",1"--version") W "ZSSWCLMS "_NREV,! Q  
	.E  I $D(V) W "???",! Q
	D INIT
	Q
INIT    ; Initialize things
	N B,D,E,I,J,K,P,S,X,Z,DT,G2,G5,IN,LS,LO,NF,SF   ; New variables.
	N FPO,KEY,LIN,MC0,PWD,CDIR,CLOG,CRLF,EOFT,SEGS,TMPZ,DASHLINE   ; New variables.
        S G2="REF*G2*",G5="REF*G5*",D=$C(126)  ; $C(126)="~"
        ; set up a date string, a line string, and a name for the file pipe
	S DT=$ZDATE($H,"YYYYMMDD"),$P(DASHLINE,"-",40)="",FP="FilePipe"
	; Open a PIPE, get pwd, the path to working directory, close the pipe.
	O FP:(command="pwd":readonly)::"PIPE" U FP R PWD C FP 
	;  Name CDIR, a directory  for today's files, and CLOG, a logfile
	S CDIR=PWD_"/claims."_DT,CLOG=CDIR_"/out/log-"_NREV_"."_DT
        ; Use linux system calls to make a dated claims directory with in and out subdirectories
        ZSY "mkdir -p "_CDIR_"/in "_CDIR_"/out"  
GETF	; Open FP again to find the filenames to be cleaned in share/, ignoring any directories.
	O FP:(command="find /home/opus/share/ -maxdepth 1 -type f":readonly)::"PIPE" 
	; Read filepath, change spaces to underscores, skip file if clean already	
	F I=1:1 U FP R X Q:$ZEOF  S FP(I,1)=X,FP(I)=$TR(X," ","_") S:X["clean" I=I-1 
	; Save NF, number of files. Close the pipe and open the CLOG file for logging
	S NF=I-1 C FP O CLOG 
	; Loop through and clean each file
	F I=1:1:NF D  
	.S FN=$P(FP(I),"/",$L(FP(I),"/")) ; Save FileName without path
	.S FPO=CDIR_"/out/"_FN_".clean"  ; FPO = path of output file
        .S SEGO=PWD_"/segfiles/"_FN  ; SEGO = a segmented file in ~/cleaning/segfiles
	. ; Write filename to Log and print to screen , then go clean the file
        .U CLOG W !,I,?4,FP(I)," > ",!,?4,FPO U 0 W !,I,?4,FP(I) D CLEAN   
	.; Now that the file is clean, move the original to "in", using spaceless name
	.ZSY "mv "_FP(I,1)_" "_CDIR_"/in/"_FN  
        C CLOG U 0 W !,"Processed ",NF," files",!  ; print to screen when done
        Q       ; all done
CLEAN   ; Clean file name from filepath FP(I,1)
        S MC0=$S($TR(FP(I,1),"MEDICAR","medicar")["medicar":"99212*0*",1:"notMedicare") ; MC0 search variable
        ; Translate upper case "MEDICARE" to lower case and check to see if filename contains either one.
        ; If so, set up to search for 99212*0*, otherwise "notMedicare" which will not be found
        O FP(I):(readonly:fixed:recordsize=32767)  ; set up for binary read, 32K chunks, not line-oriented
        U FP(I) S IN="" F J=1:1 R X Q:X=""  S IN=IN_X  ; Read chunks into one big chunk in local variable IN
        C FP(I)  ; Close input file
        S LIN=$L(IN),IN=$TR(IN,$C(10)_$C(13)),CRLF=LIN-$L(IN)  ; strip all linefeeds and carriage returns
	;See if it is a Central Labs file. If so, strip CRLF's and quit.
	I IN["NM1*41*2*CENTRAL" S LS=0 U CLOG W !,"CENTRAL LABS File: Strip CRLF only" G FINISH
        S X(0)="" O SEGO U SEGO ; open segmented file, get ready to write initial ""
        F J=1:1 W X(J-1),! Q:$P(IN,D,J)?." "  S X(J)=$P(IN,D,J)_D ; Chunk into segments in X(J) array
        S SEGS=J-1 ;  Save number of segments. Note- omit last Seg if it is all spaces
        C SEGO O CLOG U CLOG
        W !,"Found ",SEGS," segments using delimiter ",D  ; Print header 1
        W !,"Looking for search strings ",G2,", ",G5,", 99212*0*"  ; Print header 2
        W !!,"Seg",?5,"String",?75,"Len" ; Print header 3
        S (LS,SF)=0 F J=1:1:SEGS D  ; loop through segments looking for strings to excise
        .I X(J)[G2 S S=X(J),X(J)="" D  ; find and excise G2
        ..I X(J+2)[G2 S S=X(J-1)_S_X(J+1)_X(J+2),(X(J-1),X(J+1),X(J+2))="",J=J+2 Q
        ..; Two consecutive G2 segments will also have two context segments. Excise all four.
        .I X(J)[G5 S S=X(J),X(J)="" Q; same for G5
        .I X(J)[MC0 S S=X(J-1)_X(J)_X(J+1)_X(J+2),(X(J-1),X(J),X(J+1),X(J+2))="",J=J+2 Q
        .; find and excise MC0 and its context segments, one preceding and two following
        .I X(J)="" S SF=1,LS=LS+$L(S) W !,J-(X(J-1)=""),?5,S,?75,$L(S); Write what you did
        W:SF=0 !," no search strings found"  ; not found
        S IN="" F K=1:1:SEGS S IN=IN_X(K)    ; Write revised segments to file, save in IN
FINISH  O FPO:(newversion:stream:nowrap:chset="M") ; change to no-line EDI file
        U FPO W IN C FPO ; binary write
        U CLOG W !,"Stripped ",CRLF," CR and LF characters, excised ",LS," string characters."
        W !,"Input file length = ",LIN,", output file length = ",$L(IN),!,DASHLINE,!
        ZSY "cp "_FPO_" /home/opus/share" 
        Q

