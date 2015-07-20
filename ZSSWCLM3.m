ZSSWCLM3   ; Routine to remove REV*G5 and REV*G2 entries from EDI files
                ; SSW 3150527
                ; FN is path to input file. Output goes to "FN.clean"
        N X,Z,EOFT,TMPZ,DT,D,LINE,B,S,E,I,NF,IN,SEGS,KEY,G2,G2F,G5,G5F,FNO,LIN,LS,LO,CRLF,CLOG   ; New variables.
        S G2="REF*G2*",G5="REF*G5*",D=$C(126)  ; $C(126)="~"
        ; set up temp file for filenames, date string, logfile path, and  a line string
        S TMPZ="/tmp/zsytemp",DT=$ZDATE($H,"YYYYMMDD"),CLOG="claims."_DT_"/out/log2."_DT,$P(LINE,"-",40)=""
        ; Use linux system calls to make a dated claims directory with in and out subdirectories
        ZSY "mkdir claims."_DT_" ; cd claims."_DT_" ; mkdir in out"  
        ZSY "find . -maxdepth 1 -type f > "_TMPZ  ; save input filenames in temp file
        O TMPZ O CLOG S EOFT=0 U TMPZ:exception="D EOF"  ; open temp file 
        F NF=1:1 Q:EOFT  U TMPZ R FN  D   ; read filenames and clean them
        .I FN["clean" S NF=NF-1 Q   ; Do not re-clean if file has been cleaned already
        .S $E(FN,1,2)="",Z(NF)=FN  ; Strip leading "./"
        .S FNO="claims."_DT_"/out/"_FN_".clean"  ; Start an output file
        .U CLOG W !,NF,?4,FN," > ",FNO U 0 W !,NF,?4,FN," > ",FNO D CLEAN   ; log and print the filename, clean it 
        .ZSY "mv "_FN_" claims."_DT_"/in"  ; move the input file to "in" 
        U 0 W !,"Processed "_NF_" files",!  ; print to screen when done
        Q       ; all done
EOF     I '$zeof zmessage +$zstatus  ; come here on EOF error
        C TMPZ S EOFT=1  ; close and flag
        Q       ; eof handled
CLEAN ; Clean file named FN
        O FN:(readonly:fixed:recordsize=32767)  ; set up for binary read
        U FN S IN="" F I=1:1 R X Q:X=""  S IN=IN_X  ; Read input file into local variable IN
        C FN U CLOG   ; Close  input file, open log file
        S LIN=$L(IN),IN=$TR(IN,$C(10)_$C(13)),CRLF=LIN-$L(IN)  ; strip linefeeds and carriage returns
        F I=1:1 Q:$P(IN,D,I)=""  S X(I)=$P(IN,D,I)_D  ; Chunk into segments in X(I) array
        S SEGS=I-1 ;  Save number of segments. Note that last segment may be whitespace to EOL  
        S:X(SEGS)?." "1"~" SEGS=SEGS-1  ; omit last Seg if it is all spaces
        W !,"Found ",SEGS," segments using delimiter ",D  ; Print header 1
        W !,"Looking for search strings ",G2,", ",G5  ; Print header 2
        W !!,"Seg",?5,"String",?50,"Length" ; Print header 3
        S LS=0 F I=1:1:SEGS D  ; loop through segments looking for string then excise
        .I X(I)[G2 S S=X(I),LS=LS+$L(X(I)),X(I)="" D  ; find and excise G2, update S and LS
        ..I X(I-1)["NM1" S S=X(I-1)_S,LS=LS+$L(X(I-1)),X(I-1)=""  ; excise preceding NM1 if present
        ..W !,I-$L(S,D)+2,?5,S,?50,$L(S)  ; write what you did
        .I X(I)[G5 S S=X(I),LS=LS+$L(X(I)),X(I)="" W !,I,?5,S,?50,$L(S); same for G5
        W:I=1 !,G2,", ",G5," not found"  ; G2 or G5 entry not found
        O FNO:(newversion:stream:nowrap:chset="M")  ; set up for binary write
        S IN="" F I=1:1:SEGS S IN=IN_X(I)    ; Write revised segments to output file
        U FNO W IN C FNO 
        U CLOG W !,"Stripped ",CRLF," CR and LF characters, excised ",LS," string characters."
        W !,"Input file length = ",LIN,", output file length = ",$L(IN),!,LINE,!
        ZSY "cp "_FNO_" /home/opus/share" 
        Q


