ZSSWCLMS   ; Routine to remove REV*G5 entries from KEY BENEFIT ADMINISTRATORS records
                ; SSW 3150527
                ; FN is path to input file. Output goes to "FN.cleaned"
        N X,Z,EOFT,TMPZ,DT,D,LN,B,S,E,I,J,IN,Segs,KEY,G5,KF,FNO,LIN,LS,LO,CRLF,CLOG   ; New variables.
	S TMPZ="/tmp/zsytemp",DT=$ZDATE($H,"YYYYMMDD"),CLOG="claims."_DT_"/out/log."_DT,$P(LN,"-",40)=""
	ZSY "mkdir claims."_DT_" ; cd claims."_DT_" ; mkdir in out"
	ZSY "find . -maxdepth 1 -type f > "_TMPZ
	O TMPZ O CLOG S EOFT=0 U TMPZ:exception="D EOF"
	F J=1:1 Q:EOFT  U TMPZ R FN S $E(FN,1,2)="",Z(J)=FN D  
	.S FNO="claims."_DT_"/out/"_FN_".cleaned" 
	.U CLOG W !,J,?4,FN," > ",FNO U 0 W !,J,?4,FN," > ",FNO D CLEAN 
	.ZSY "mv "_FN_" claims."_DT_"/in"
	U 0 W !,"End",!
	Q	
EOF	I '$zeof zmessage +$zstatus
	C TMPZ S EOFT=1
	Q
CLEAN ; Clean file named FN
        O FN:(readonly:fixed:recordsize=32767)  ; set up for binary read
	U FN S IN="" F I=1:1 R X Q:X=""  S IN=IN_X  ; Read input file into local variable IN
        U CLOG C FN S D="NM1*85",KEY="KEY BENEFIT",G5="REF*G5*"  ; Close file, Set variables
	S LIN=$L(IN),IN=$TR(IN,$C(10)_$C(13)),CRLF=LIN-$L(IN)
        S X(1)=$P(IN,D) F I=2:1 Q:$P(IN,D,I)=""  S X(I)=D_$P(IN,D,I)  ; Chunk into segments in X(I) array
        S Segs=I-1  ; 
	W !,"Found ",Segs," segments using delimiter ",D  ; Print header
	W !,"Looking for segments containing ",KEY," with string ",G5  ; Print header 1
	W !!,"Segment",?10,"String",?40,"Location",?50,"Length"  ; Print header 2
	S KF=0,LS=0 F I=1:1:Segs I X(I)[KEY S KF=1 D  ; loop through segments looking for KEY then excise G5
	.I X(I)[G5 D  
	..S B=$F(X(I),G5)-$L(G5),E=$F(X(I),$C(126),B)-1,S=$E(X(I),B,E),LS=LS+$L(S),$E(X(I),B,E)="";  $C(126)="~"
	..W !,I,?10,S,?40,B,?50,$L(S)  ; write what you did
	.E  W !,I,?10,G5," not found"  ; G5 entry not found
	.Q
	W:'KF !,KEY," not found"  ; KEY entry not found
	O FNO:(newversion:stream:nowrap:chset="M")  ; set up for binary write
	U FNO S LO=0  ; set up output file
	F I=1:1:Segs W X(I) S LO=LO+$L(X(I))    ; Write revised segments to output file
        C FNO U CLOG W !,"Stripped ",CRLF," CR and LF characters, excised ",LS," string characters."
	W !,"Input file length = ",LIN,", output file length = ",LO,!,LN,!
	ZSY "cp "_FNO_" /home/opus/share" 
        Q

