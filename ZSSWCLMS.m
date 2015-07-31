SWCLM4   ; Routine to remove REV*G5 and REV*G2 entries from EDI files
                ; SSW 3150527
           ;Place all files to be cleaned in directory ~/cleaning, 
           ; FN is path to input file. Output goes to "FN.clean"
INIT    N X,Z,EOFT,P,PWD,TMPZ,DT,D,DASHLINE,B,S,E,I,J,K,NREV,NF,IN,SEGS,KEY,G2,G5,MC0,SF,FNO,LIN,LS,LO,CRLF,CDIR,CLOG   ; New variables.
        S NREV=4  ; Revision number of this routine
        S G2="REF*G2*",G5="REF*G5*",D=$C(126)  ; $C(126)="~"
        ; set up a temp file for filenames, a date string, a logfile path, and  a line string
	S DT=$ZDATE($H,"YYYYMMDD")
	S FP="FilePipe"
	O FP:(command="pwd":readonly)::"PIPE" U FP R PWD C FP
	S CDIR=PWD_"/claims."_DT,CLOG=CDIR_"/out/log"_NREV_"."_DT,$P(DASHLINE,"-",40)=""
        ; Use linux system calls to make a dated claims directory with in and out subdirectories
        ZSY "mkdir -p "_CDIR_"/in "_CDIR_"/out"  
GETF   	O FP:(command="find /home/opus/share/ -maxdepth 1 -type f":readonly)::"PIPE"
	F I=1:1 U FP R X Q:$ZEOF  S FN(I)=$TR(X," ","_") S:X["clean" I=I-1 ; Read filenames, no spaces, skip if clean already	
	C FP S NF=I-1 O CLOG ; Close FilePipe, Save Number of Files, Open Log
	F I=1:1:NF D  ; Go through and clean each file
	.S FN=$P(FN(I),"/",$L(FN(I),"/")) ; Save FileName without path
	.S FNO=CDIR_"/out/"_FN_".clean"_NREV  ; Name of output file
        .S SEGO=PWD_"/segfiles/"_$P(FN(I),"/",$L(FN(I),"/"))  ; Name of a segmented file in segfile directory
        .U CLOG W !,I,?4,FN(I)," > ",!,?4,FNO U 0 W !,I,?4,FN(I) D CLEAN   ; Write the filename to Log and 0, then clean it
	.ZSY "cp "_FN(I)_" "_CDIR_"/in"  ; copy the input file to "in" 
        C CLOG U 0 W !,"Processed ",NF," files",!  ; print to screen when done
        Q       ; all done
CLEAN ; Clean file named FN(I)
        S MC0=$S($TR(FN(I),"MEDICAR","medicar")["medicar":"99212*0*",1:"notMedicare") ; MC0 search variable
        ; Translate upper case "MEDICARE" to lower case and check to see if filename contains either one.
        ; If so,  set up to search for 99212*0*, otherwise "notMedicare" which will not be found
        O FN(I):(readonly:fixed:recordsize=32767)  ; set up for binary read
        U FN(I) S IN="" F J=1:1 R X Q:X=""  S IN=IN_X  ; Read input file into local variable IN
        C FN(I)  ; Close input file
        S LIN=$L(IN),IN=$TR(IN,$C(10)_$C(13)),CRLF=LIN-$L(IN)  ; strip linefeeds and carriage returns
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
FINISH  O FNO:(newversion:stream:nowrap:chset="M") ; change to no-line EDI file
        U FNO W IN C FNO ; binary write
        U CLOG W !,"Stripped ",CRLF," CR and LF characters, excised ",LS," string characters."
        W !,"Input file length = ",LIN,", output file length = ",$L(IN),!,DASHLINE,!
        ZSY "cp "_FNO_" /home/opus/share" 
        Q

