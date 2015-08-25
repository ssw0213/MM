ZSSWCLM   ; Routine to remove CR and LF characters from EDI files, leaving only "~" as 
	; segment delimiter. All files but CENTRAL LABS need REV*G5 and REV*G2 segments
	; removed. Files with "Medicare" in the filename need zero-charge entries removed.
                ; SSW 3150527
        ; Place all files to be cleaned in directory /home/opus/share/
        ; FP() is path to input file.
	; Output will be found in ~/cleaning/claims.<date>/out/FN.clean
	; Start routine with "clean" script 
	Q  ; Not to be run from top.
START	; Look for -v or --version in command line of starter routine
	N NREV,V S NREV="v1.1"  ; Revision number of this routine
	S V=$ZCMDLINE  ; Get arguments from command line of calling script
	I $L(V) D  Q
	. ; If this is a version request, print version and quit.
	.I $G(V)?1(1"-v",1"--version") W "ZSSWCLMS "_NREV,! Q  
	.E  I $D(V) W "Use -v or --version as command line options, or leave empty to run.",! Q
	D INIT
	Q
INIT    ; Initialize things
	N D,I,J,K,N,S,X,DT,G2,G5,IN,JX,LS,LO,LX,NF,SF,FP   ; New variables.
	N FPO,KEY,LIN,MCR,USERHOME,CDIR,CLOG,CRLF,EOFT,SEGS,TMPZ,DASHLINE   ; New variables.
        S G2="REF*G2*",G5="REF*G5*",D=$C(126)  ; $C(126)="~"
        ; set up a date string, a line string, and a name for the file pipe
	S DT=$ZDATE($H,"YYYYMMDD"),$P(DASHLINE,"-",40)=""
	;--------------------------------------------
	S FP="FilePipe"
	; Open a PIPE, get USERHOME, close the pipe.
	O FP:(command="echo ~":readonly)::"PIPE" U FP R USERHOME C FP 
	;--------------------------------------------
	;  Name CDIR, a directory  for today's files, and CLOG, a logfile
	S CDIR=USERHOME_"/cleaning/claims."_DT,CLOG=CDIR_"/out/log-"_NREV_"."_DT
        ; Use linux system calls to make a dated claims directory with in and out subdirectories
        ZSY "mkdir -p "_CDIR_"/in "_CDIR_"/out"  
GETF	; Open FP to look in share/ for filenames to be cleaned, ignoring any directories there.
	S FP="FilePipe"
	O FP:(command="find /home/opus/share/ -maxdepth 1 -type f":readonly)::"PIPE" 
	; Read filepath, change spaces to underscores, skip file if clean already	
	F I=1:1 U FP R X Q:$ZEOF  S FP(I,1)=X,FP(I)=$TR(X," ","_") S:X["clean" I=I-1 
	; Save NF, number of files. Close the pipe and open the CLOG file for logging
	S NF=I-1 C FP O CLOG:NEWVERSION
	; Loop through and clean each file
	F I=1:1:NF D  
	.S FN=$P(FP(I),"/",$L(FP(I),"/")) ; Save FileName without path
	.S FPO=CDIR_"/out/"_FN_".clean"  ; FPO = path of output file
        .S SEGO=USERHOME_"/cleaning/segfiles/"_FN  ; SEGO = a segmented file in ~/cleaning/segfiles
	. ; Write filename to Log and print to screen , then go clean the file
        .U CLOG W !,I," ",FPO U 0 W !,I,?4,FP(I) D CLEAN   
	.; Now that the file is clean, move the original to "in", using spaceless name
	.ZSY "mv "_FP(I,1)_" "_CDIR_"/in/"_FN  
        C CLOG U 0 W !,"Processed ",NF," files",!  ; print to screen when done
        Q       ; all done
CLEAN   ; Clean file name from filepath FP(I,1)
        S MCR=$TR(FN,"MEDICAR","medicar")["medicar" 
        ; Translate upper case "MEDICARE" to lower case and check to see if filename contains either one.
        ; If filename contains "Medicare", set MCR flag and search for zero charges (later)
        O FP(I):(readonly:fixed:recordsize=32767)  ; set up for binary read, 32K chunks, not line-oriented
        U FP(I) S IN="" F J=1:1 R X Q:X=""  S IN=IN_X  ; Read chunks into one big chunk in local variable IN
        C FP(I)  ; Close input file
        S LIN=$L(IN),IN=$TR(IN,$C(10)_$C(13)),CRLF=LIN-$L(IN)  ; strip all linefeeds and carriage returns
	;See if it is a Central Labs file. If so, strip CRLF's and quit.; Deprecated:clean Central too
	;I IN["NM1*41*2*CENTRAL" S LS=0 U CLOG W !,"CENTRAL LABS File: Strip CRLF only" G FINISH
        S X(0)="" O SEGO U SEGO ; open segmented file, get ready to write initial ""
        F J=1:1 W X(J-1),! Q:$P(IN,D,J)?." "  S X(J)=$P(IN,D,J)_D ; Chunk into segments in X(J) array
        S SEGS=J-1 ;  Save number of segments. Note- omit last Seg if it is all spaces
        C SEGO O CLOG U CLOG
        W !,"Found ",SEGS," segments using delimiter ",D  ; Print header 1
        W:MCR !,"This is a Medicare file. Searching for zero-charges containing 992nn*0*."
	W ! W $S(MCR:"Also s",1:"S"),"earching for ",G2," and ",G5  ; Print header 2
        W !!,"Seg",?5,"String",?75,"Len" ; Print header 3
        S (LS,SF)=0 F J=1:1:SEGS D  ; loop through segments looking for strings to excise
        .I X(J)[G2 D XG I X(J+2)[G2 D XGG ; find and excise G2
        .I X(J)[G5 D XG I X(J+2)[G5 D XGG ; same for G5
        .; In files with "Medicare" in the name, look for zero charges
        .I MCR,X(J)?1"SV2*0521*HC:992"2N1"*0*".E S SF=2 D XMC0 
        .I SF=2 S SF=1,LS=LS+$L(S) W !,JX,?5,S,?75,$L(S); Write what you did
        W:SF=0 !," no search strings found"  ; not found
        S IN="" F K=1:1:SEGS S IN=IN_X(K)    ; Write revised segments to file, save in IN
	G FINISH
XG	S SF=2,JX=J,S=X(J),X(J)="" ; Excise the G segment and save it for the log.
	Q
XGG	; Two consecutive G segments will also have two context segments. Excise all four.
        S S=X(J-1)_S_X(J+1)_X(J+2),(X(J-1),X(J+1),X(J+2))="",J=J+2 
	Q
XMC0	; Excise zero-dollar charges in Medicare files. 
    ; Examination of claims files seems to show this:
    ; Charges are sent in loops of up to nine 4-segment entry groups each starting with an "LX*n~" segment,
    ; where "n" is the number of the entry group.
    ; The zero charge entry group will have "SV2*0521*HC:992nn*0*" in the second segment,
    ; usually in the second (LX*2~) entry group.
    ; The "992nn" will be a CPT visit code, probably 99202, 99211, 99212, or 99213.
    ; In a zero charge entry, this will be followed by a charge amount of *0*.
    ; This second segment along with the third needs to be pushed toward the end of the loop to be excised later.
    ; The first (LX*n~) and fourth segments contain sequence numbers that must be retained in place.
    ; Any subsequent charges need to be pulled forward between the first (LX*n) and fourth segment of the group.
	;
	S SF=2,JX=J,LX=$E(X(J+3),1,3) 
	; Save SF= flag: print to logfile, JX=line of zero-charge segment, LX start of the next entry group.
   	I LX'="LX*" D  Q ; If LX is not an LX*n entry then there are no more charges.
   	.; Check for error, warn and continue, do not stop.
   	.I LX'="HL*" U CLOG W !,JX," ERROR: Next entry identifier is "_LX_", not HL*." 
   	..U 0 W !,"ERROR: see log"
   	.; save these four last four segments to S for the log, then excise them. 
	.S S=X(J-1)_X(J)_X(J+1)_X(J+2),(X(J-1),X(J),X(J+1),X(J+2))="",J=J+4  ; End of loop.
	ELSE  D ; Bubble rotate 2nd and 3rd segments toward the end and repeat the loop.
	.S X=X(J),X(J)=X(J+4),X(J+4)=X,X=X(J+1),X(J+1)=X(J+5),X(J+5)=X,J=J+4
	.G XMC0 ; Recursive loop.
	Q  ; End of XMCO
FINISH  O FPO:(newversion:stream:nowrap:chset="M") ; change to no-line EDI file
        U FPO W IN C FPO ; binary write
        U CLOG W !,"Stripped ",CRLF," CR and LF characters, excised ",LS," string characters."
        W !,"Input file length = ",LIN,", output file length = ",$L(IN),!,DASHLINE,!
        ZSY "cp "_FPO_" /home/opus/share" 
        Q



