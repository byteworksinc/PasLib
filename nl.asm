	keep	obj/nl
	mcopy nl.macros
****************************************************************
*
*  Native Code Pascal Libraries 1.0
*
*  These libraries are for use with the 65816 ORCA/Pascal
*  native code compiler.
*
*  Copyright 1987
*  Byte Works, Inc.
*  All rights reserved.
*
*  By Mike Westerfield and Phil Montoya
*  May 1987
*
****************************************************************
*
*  10 Nov 89
*  Mike Westerfield
*
*  Duplications between this library and C have been moved to
*  SYSLIB.
*
****************************************************************
*
Dummy	start
	end

****************************************************************
*
*  ~_COut - Write a character
*
*  Inputs:
*	A - character to write
*	3 - address of output file buffer
*
*  Notes:
*	X,Y are undisturbed
*
****************************************************************
*
~_COut	start
	longa on
	longi on
	using ~FileCom
ch	equ	1	character to write
ptr	equ	3	pointer to file variable
return	equ	13	RETURN key code

	and	#$00FF
	pha		set up space for CH, PTR
	pha
	pha
	tsc		preserve S
	phx		save X, Y
	phy
	ldy	3	get buffer pointer
	ldx	5
	phd		set up DP
	tcd
	phb		set up data bank
	phk
	plb
	sec		point to file, not buffer
	tya
	sbc	#~flHeader
	sta	ptr
	txa
	sbc	#0
	sta	ptr+2
	ldy	#~flKind	error if file is not open
	lda	[ptr],Y
	bne	la1
	error #2
	bra	lb2
la1	ldy	#~flRef	if standard out then
	lda	[ptr],Y
	bne	lb1
	lda	ch	  if CR then
	cmp	#return
	bne	lb0
	putcr		    do system CR
	bra	lb2	  else
lb0	putc	ch	    write to standard out
	bra	lb2	else
lb1	sta	wrRef	  save ref num for write call
	ldx	ch	  set character to write
	stx	lch
	lda	#0	  if this is an eoln then
	cpx	#return	    eoln := true
	bne	lb1a	  else
	inc	a	    eoln := false
lb1a	ldy	#~flEOLN	  endif
	sta	[ptr],Y
	write wrDCB	  write the character
	bcc	lb2	endif
	error #4
lb2	plb		reset data bank
	pld		reset DP
	ply		rest X, Y
	plx
	pla		remove garbage from stack
	pla
	pla
	rtl

wrDCB	anop
wrRef	ds	2
	dc	a4'lch'
	dc	i4'1'
	ds	4

lch	ds	2
	end

****************************************************************
*
*  ~Check - check a two byte value to insure it is in a subrange
*
*  Inputs:
*	X - lowest legal value
*	Y - highest legal value
*	A - value to check
*
****************************************************************
*
~Check	start
	longa on
	longi on

	pha		save value
	tya		error if A > Y
	sec
	sbc	1,S
	beq	er3
	bvs	er1
	eor	#$8000
er1	bpl	error
er3	txa		error if A < X
	sec
	sbc	1,S
	beq	lb1
	bvs	er2
	eor	#$8000
er2	bpl	lb1
error	error #1	subrange exceeded
lb1	pla		recover value
	rtl
	end

****************************************************************
*
*  ~CheckLong - check a two byte value to insure it is in a subrange
*
*  Inputs:
*	low - lowest legal value
*	hi - highest legal value
*	low+4 - value to check
*
****************************************************************
*
~CheckLong start

	sub	(4:hi,4:low),0

	ph4	low	error if A < low
	ph4	low+4
	jsl	~GrtL
	bne	error
	ph4	low+4	error if A > hi
	ph4	hi
	jsl	~GrtL
	beq	lb1
error	error #1	subrange exceeded

lb1	return
	end

****************************************************************
*
*  ~CheckPtr - check a pointer to insure it is not nil
*
*  Inputs:
*	1,S - return address
*	4,S - pointer
*
****************************************************************
*
~CheckPtr start
	longa on
	longi on

	lda	4,S
	ora	6,S
	bne	lb1
	error #1	subrange exceeded
lb1	rtl
	end

****************************************************************
*
*  ~ClearMem - zero an area of memory
*
*  Inputs:
*	size - # bytes to clear
*	ptr - pointer to area to clear
*
****************************************************************
*
~ClearMem start
	longa on
	longi on

	sub	(4:ptr,2:size),0

	short M
	lda	#0
	ldy	size
	dey
	beq	lb2
lb1	sta	[ptr],Y
	dey
	bne	lb1
lb2	sta	[ptr]
	long	M
	return
	end

****************************************************************
*
*  ~Close - Close a file
*
*  Inputs:
*	1,S - return address
*	4,S - pointer to file buffer
*
****************************************************************
*
~Close	start
	longa on
	longi on
	using ~FileCom
ptr	equ	3	file pointer for call to ~_COut
return	equ	13	RETURN key code

	sub	(4:filePtr),7
	phb
	phk
	plb

	move4 filePtr,ptr	set the pointer for calls to ~_COut
	sub4	filePtr,#~flHeader	point to file info
	ldy	#~flKind	if open for text output then
	lda	[filePtr],Y
	and	#6
	cmp	#6
	bne	rt2
	ldy	#~flEOLN	  if the last char was not a return then
	lda	[filePtr],Y
	bne	rt1
	lda	#return	    writeln
	jsl	~_COut
rt1	anop		  endif
rt2	anop		endif
	ldy	#~flKind	skip if never opened
	lda	[filePtr],Y
	beq	lb1
	ldy	#~flRef	close the file
	lda	[filePtr],Y
	sta	clRef
	close clDCB
	bcc	lb1
	error #4
lb1	ldy	#~flRef	zero the file reference # and kind
	lda	#0
	sta	[filePtr],Y
	ldy	#~flKind
	sta	[filePtr],Y
	plb
	return

clDCB	anop		CLOSE DCB
clRef	ds	2
	end

****************************************************************
*
*  ~CnvIS - convert integer to string
*
*  Inputs:
*	num - integer to convert
*
*  Outputs:
*	stack - length of result string
*	stack-1 - pointer to result string
*
****************************************************************
*
~CnvIS	start
	longa on
	longi on
dpage	equ	1	direct page
retAddr	equ	3	return address
sLen	equ	6	string length
sAddr	equ	8	string address
num	equ	8	number to convert

	lda	1,S	make room for result
	pha		  and move return address
	lda	5,S
	sta	3,S
	phd		save direct page
	tsc		set up direct page
	tcd

	ph4	num	integer to convert
	lda	#20	set string length
	sta	sLen
	ldx	#0
	jsr	~GetSBuffer	get a string buffer
	sta	sAddr
	stx	sAddr+2
	bcs	err
	phx		string pointer
	pha
	ph2	sLen	string length
	ph2	#1	signed flag
	_Long2Dec
	bcc	cv1
	stz	sLen
	bra	rts

cv1	ldy	#0	string is right justifed
	short M	  so point to first non blank char
cv2	lda	#' '
	cmp	[sAddr],y
	bne	cv3
	iny
	dec	sLen
	bne	cv2

cv3	long	M	add disp to string pointer
	tya
	clc
	adc	sAddr
	sta	sAddr
	bcc	rts
	inc	sAddr+2

rts	pld		restore direct page
	rtl

err	error #5	out of memory
	stz	sLen	return 0
	pla
	bra	rts
	end

****************************************************************
*
*  ~CnvL2 - convert a long integer to a two byte integer
*
*  Inputs:
*	4,S - long integer
*
*  Outputs:
*	A - result
*
****************************************************************
*
~CnvL2	start

	lda	6,S	x := high word
	tax
	lda	4,S	a := low word
	bpl	lb1	make sure the range is valid
	inx
lb1	txy
	beq	lb2
	pha
	error #1	subrange exceeded
	pla
lb2	tax		remove parm from stack
	lda	0,S
	sta	4,S
	lda	2,S
	sta	6,S
	pla
	pla
	txa
	rtl
	end

****************************************************************
*
*  ~CnvSI - convert string to integer
*
*  Inputs:
*	1,S - return address
*	4,S - length of string
*	6,S - address of string
*
*  Outputs:
*	a - integer value of string
*
****************************************************************
*
~CnvSI	start
	longa on
	longi on

	sub	(2:tLen,4:tAddr),0

	pea	0	space for result
	ph4	tAddr	convert string to standard form,
	ph2	tLen	 leaving addr and length on stack
	jsr	~StringToStandard
	ph2	#1	result is signed
	_Dec2Int
	plx		return the result
	return 2
	end

****************************************************************
*
*  ~CnvSL - convert string to long integer
*
*  Inputs:
*	1,S - return address
*	4,S - length of string
*	6,S - address of string
*
*  Outputs:
*	a - integer value of string
*
****************************************************************
*
~CnvSL	start
	longa on
	longi on
return	equ	0

	sub	(2:tLen,4:tAddr),0

	ph4	#0	space for result
	ph4	tAddr	convert string to standard form,
	ph2	tLen	 leaving address and length on stack
	jsr	~StringToStandard
	ph2	#1	result is signed
	_Dec2Long
	ply		get the result
	plx

	lda	return+1	set return address
	sta	tAddr+2
	lda	return
	sta	tAddr+1
	clc		restore stack
	tdc
	adc	#tAddr
	pld		restore direct page
	tcs
	tya		return result in A, X
	rtl
	end

****************************************************************
*
*  ~Concat - concatonate strings
*
*  Inputs:
*	1,S - return address
*	4,S - number of string
*	6,S - array[cNum] of strings and thier length
*
*  Outputs:
*	4,S - length of result string
*	6,S - pointer to result string
*
****************************************************************
*
~Concat	start
	longa on
	longi on
maxString equ	32767

rLen	equ	0	return string length
rAddr	equ	2	return string address
index	equ	6	computed index into array
tIndx	equ	8	temp index
ptrIndx	equ	10	temp index
ptr	equ	12	temp pointer
ptr2	equ	16	temp pointer
tsNum	equ	20	temp string number
retAddr	equ	22	return address
sNum	equ	25	number of strings to copy
array	equ	27	array of strings

	tdc		get old direct page
	tax
	tsc
	sec
	sbc	#21
	tcd		set direct page
	dec	a
	tcs		set stack pointer
	phx		save old direct page

	lda	sNum	compute the array index
	dec	a
	sta	index
	asl	a
	adc	index
	asl	a
	sta	index
;
;  Compute total length of strings by calling the length function for each one
;
	sta	tIndx	initialize index
	lda	sNum	initialize string counter
	sta	tsNum
	stz	rLen	init length counter

cn1	ldx	tIndx	know there are at least two strings
	lda	array+4,X	compute length
	pha
	lda	array+2,X
	pha
	lda	array,X
	pha
	jsl	~Length
	clc		add length
	adc	rLen
	sta	rLen
cn3	sec		update string index
	lda	tIndx
	sbc	#6
	sta	tIndx
	dec	tsNum	next string
	bne	cn1

	lda	rLen	truncate string if overflow
	bpl	cn4
	lda	#maxString
cn4	beq	rts	string may be empty
	ldx	#0
	jsr	~GetSBuffer	allocate a buffer
	sta	rAddr
	stx	rAddr+2
	bcs	err
;
;  Copy each string in the array of strings
;
	lda	index	initialize index counter
	sta	tIndx
	lda	sNum	initialize string counter
	sta	tsNum
	stz	rLen	initialize string index

cn5	ldx	tIndx	know there are at least two strings
	lda	array+4,X	convert to standard form
	pha
	lda	array+2,X
	pha
	lda	array,X
	pha
	jsr	~StringToStandard
	pla		if length is 0, skip it
	bne	cn6
	pla		  (dump string addr)
	pla
	bra	cn7
cn6	sta	ptrIndx	else copy over the string
	pla
	sta	ptr
	pla
	sta	ptr+2
	jsr	~concopy
	bcs	err2

cn7	sec		update string index
	lda	tIndx
	sbc	#6
	sta	tIndx
	dec	tsNum	next string
	bne	cn5
	lda	rLen	check for 1 character string and
	cmp	#1	  convert to character
	bne	rts
	lda	[rAddr]
	and	#$00FF
	sta	rAddr+2
	lda	#$FFFF
	sta	rlen
	sta	rAddr

rts	ldx	index	return string
	lda	rLen
	sta	array,X
	lda	rAddr
	sta	array+2,X
	lda	rAddr+2
	sta	array+4,X

	lda	retAddr+1	set return address
	sta	array-2,X
	lda	retAddr
	sta	array-3,X
	clc		update stack
	tdc
	adc	index
	adc	#23
	pld		restore direct page
	tcs
	rtl

err2	dec	rlen	truncate the string
	bra	rts

err	error #5	out of memory
	stz	rLen	return 0
	bra	rts
;
;  Concatonate copy string routine
;
~concopy anop

	clc		truncate string if overflow
	lda	ptrIndx	if ptrIndx + rlen < 0
	adc	rLen
	bpl	cp1
	sec		  overflow = true
	php
	lda	#maxString	  ptrIndx = maxString - rLen
	sbc	rLen
	sta	ptrIndx
	bra	cp2
cp1	clc		else overflow = false
	php

cp2	ldy	ptrIndx	make sure there is stuff to copy
	beq	cp5
	clc		get to address
	lda	rLen
	adc	rAddr
	sta	ptr2
	lda	#0
	adc	rAddr+2
	sta	ptr2+2
	clc		update index
	lda	rLen
	adc	ptrIndx
	sta	rLen

	tya		move one byte if the move length is odd
	lsr	a
	bcc	cp3
	short M
	lda	[ptr]
	sta	[ptr2]
	long	M
	inc4	ptr
	inc4	ptr2
	dey
	beq	cp5

cp3	dey		move the bytes
	dey
cp4	lda	[ptr],Y
	sta	[ptr2],Y
	dey
	dey
	bpl	cp4
cp5	plp
	rts
	end

****************************************************************
*
*  ~Copy - copies characters from a string
*
*  Inputs:
*	1,S - return address
*	4,S - number of characters to copy
*	6,S - index to start copy at
*	8,S - string maximum length
*	10,S - string address
*
*  Outputs:
*	4,S - length of result string
*	6,S - pointer to result string
*
****************************************************************
*
~Copy	start
	longa on
	longi on
rLen	equ	0	return string length
rAddr	equ	2	return string address
ptr	equ	6	temporary pointer
retAddr	equ	10	return address
cNum	equ	13	number of chars to copy
index	equ	15	index to copy at
sLen	equ	17	copy string length
sAddr	equ	19	copy string address

	tdc		get the parameters
	tax
	tsc
	sec		get some zero page
	sbc	#9
	tcd		set direct page
	dec	a
	tcs		set stack pointer
	phx		save old direct page

	stz	rLen	in case of error set string to null

	lda	cNum	make sure there are bytes to delete
	jeq	rts
	lda	index	make sure the index is not zero
	jeq	rts

	ph4	sAddr	convert to standard form
	ph2	sLen
	jsr	~StringToStandard
	pl2	sLen
	pl4	sAddr
	lda	sLen	make sure the index is within the string
	beq	rts
	cmp	index
	blt	rts

	dec	index	adjust index to zero
	sec		if (tLen - index) >= cNum then
	sbc	index
	cmp	cNum	  rLen = cNum
	blt	cp1
	lda	cNum	else rLen = tLen - index

cp1	cmp	#1	if this is a character
	bne	cp2
	lda	#$FFFF	  rLen = -1
	sta	rLen
	ldy	index
	lda	[sAddr],Y	  rAddr+2 = [tAddr],index
	and	#$00FF
	sta	rAddr+2
	stz	rAddr	  rAddr = 0
	bra	rts

cp2	sta	rLen	else
	ldx	#0
	jsr	~GetSBuffer	  get a string buffer
	sta	rAddr
	stx	rAddr+2
	jcs	err

	clc		compute from address
	lda	sAddr
	adc	index
	sta	sAddr
	bcc	cp2a
	inc	sAddr+2
cp2a	move4 rAddr,ptr

	lda	rLen	move one byte if the move length is odd
	tay
	lsr	a
	bcc	cp3
	short M
	lda	[sAddr]
	sta	[ptr]
	long	M
	inc4	sAddr
	inc4	ptr
	dey
	beq	rts

cp3	dey		move the bytes
	dey
cp4	lda	[sAddr],Y
	sta	[ptr],Y
	dey
	dey
	bpl	cp4

rts	lda	rLen	move over the return value
	sta	sLen
	move4 rAddr,sAddr
	lda	retAddr+1	get the return address
	sta	sLen-2
	lda	retAddr
	sta	sLen-3
	clc		fix the stack
	tdc
	adc	#13
	pld		restore old direct page
	tcs
	rtl

err	error #5	out of memory
	bra	rts
	end

****************************************************************
*
*  ~Delete - deleats characters from a string
*
*  Inputs:
*	1,S - return address
*	4,S - number of characters to delete
*	6,S - index to start delete at
*	8,S - string maximum length
*	10,S - string address
*
****************************************************************
*
~Delete	start
	longa on
	longi on
tIndx	equ	0	temp index
tAddrS	equ	2	temp string pointer
tAddrF	equ	6
lAddr	equ	10	local string pointer, length
lLen	equ	14

	sub	(2:cNum,2:index,2:tlen,4:tAddr),16

	lda	cNum	make sure there are bytes to delete
	jeq	rts
	lda	index	make sure the index is not zero
	jeq	rts

	ph4	tAddr	convert to standard form
	ph2	tLen
	jsr	~StringToStandard
	pl2	lLen
	pl4	lAddr
	lda	lLen	quit if length is zero
	beq	rts

	lda	index	make sure the index is within the string
	cmp	lLen
	bgt	rts

	dec	index	adjust index to 0
	clc		if deleting to end of line then
	lda	index	  it is not necessary to move
	adc	cNum	  characters you only have to truncate
	sta	tIndx	  the line
	cmp	lLen
	bge	dl2
;
;  Deleting characters inside string must compact end characters
;
	sec		compute number of bytes to move
	lda	lLen
	sbc	tIndx
	beq	rts
	tax
	clc		compute a source pointer
	lda	index
	adc	lAddr
	sta	tAddrS
	lda	#0
	adc	lAddr+2
	sta	tAddrS+2
	clc		compute a from pointer
	lda	tIndx
	adc	lAddr
	sta	tAddrF
	lda	#0
	adc	lAddr+2
	sta	tAddrF+2
	clc		update the index
	txa
	adc	index
	sta	index

	ldy	#0	move one byte if the move length is odd
	txa
	lsr	a
	tax
	bcc	dl1
	short M
	lda	[tAddrF]
	sta	[tAddrS]
	long	M
	iny
	txa
	beq	dl2

dl1	lda	[tAddrF],Y	move the bytes
	sta	[tAddrS],Y
	iny
	iny
	dex
	bne	dl1
;
;  Set the end of string marker
;
dl2	lda	tLen	if the string has a length byte then
	inc	a
	bpl	dl3
	short M
	lda	index
	sta	[tAddr]
	long	M
	bra	rts	else
dl3	lda	#0	  set end of string marker
	ldy	index
	short M
	sta	[lAddr],Y
	long	M

rts	return
	end

****************************************************************
*
*  ~DisposeOpenRec - dispose of the current open file chain
*
*  Inputs:
*	~fileRecBuff - pointer to current file info record
*
*  Outputs:
*	~fileRecBuff - pointer to old file info record
*	thisFile - current open file pointer
*	~fileBuff - chain to other open files
*
****************************************************************
*
~DisposeOpenRec start
	using ~FileCom
p1	equ	3	local work pointer

	phb		use local data bank
	phk
	plb
	pha		create direct page work space
	pha
	phd
	tsc
	tcd
;
;  dispose of all open files at this level
;
df1	lda	~thisFile	while thisFile <> nil do begin
	ora	~thisFile+2
	beq	df2
	add4	~thisFile,#~flHeader	  close(thisFile);
	ph4	~thisFile
	jsl	~Close
	move4 ~fileBuff,p1	  thisFile := ~fileBuff^.thisFile;
	ldy	#2
	lda	[p1]
	sta	~thisFile
	lda	[p1],Y
	sta	~thisFile+2
	ldy	#4	  ~fileBuff := ~fileBuff^.next;
	lda	[p1],Y
	sta	~fileBuff
	ldy	#6
	lda	[p1],Y
	sta	~fileBuff+2
	bra	df1	  end;
df2	anop
;
;  dispose of the current record, resoring the old one
;
	move4 ~fileRecBuff,p1	set up the pointer
	lda	[p1]	save thisFile
	sta	~thisFile
	ldy	#2
	lda	[p1],Y
	sta	~thisFile+2
	ldy	#4	save ~fileBuff
	lda	[p1],Y
	sta	~fileBuff
	ldy	#6
	lda	[p1],Y
	sta	~fileBuff+2
	ldy	#8	save ~fileRecBuff
	lda	[p1],Y
	sta	~fileRecBuff
	ldy	#10
	lda	[p1],Y
	sta	~fileRecBuff+2
	ph4	p1	dispose of old file record
	jsl	~Dispose
;
;  Restore registers and return
;
	pld		reset DP
	pla		remove work space
	pla
	plb		restore data bank
	rtl
	end

****************************************************************
*
*  ~DisposeStrHeap - disposes of string heap
*
*  Inputs:
*	~StringList - string list pointer
*
****************************************************************
*
~DisposeStrHeap start
	longa on
	longi on
r0	equ	0	temp pointer

	ph4	r0	save 0 page location
	phb		set data bank reg
	phk
	plb
	move4 ~StringList,r0	get list pointer

dp1	lda	r0	while list is not nil
	ora	r0+2
	beq	rts
	ph4	r0	  set up for dispose
	ldy	#2	  get next pointer
	lda	[r0]
	tax
	lda	[r0],Y
	sta	r0+2
	stx	r0
	jsl	~Dispose
	bra	dp1
rts	stz	~StringList
	stz	~StringList+2
	plb		restore data bank reg
	pl4	r0	restore 0 page location
	rtl
	end

****************************************************************
*
*  ~EOF - Check for end of file
*
*  Inputs:
*	FILE_PTR - pointer to file buffer variable
*
*  Outputs:
*	A - end of file flag
*
****************************************************************
*
~EOF	start
	longa on
	longi on
	using ~FileCom
filePtr	equ	4

	tsc		set up direct page
	phd
	tcd
	sub4	filePtr,#~flHeader	point to file variable, not buffer
	ldy	#~flKind	error if file is not open
	lda	[filePtr],Y
	bne	lb1
	error #2	(unopened file)
	lda	#0
	bra	lb2
lb1	ldy	#~flEOF	set EOF
	lda	[filePtr],Y
lb2	tay
	lda	2	remove extra word from stack
	sta	6	 and reset DP
	lda	0
	sta	4
	pld
	pla
	pla
	tya
	rtl
	end

****************************************************************
*
*  ~EOFStdIn - Check for end of file on standard in
*
*  Outputs:
*	result - end of file flag
*
****************************************************************
*
~EOFStdIn start
	longa on
	longi on

	lda	~EOFInput
	rtl
	end

****************************************************************
*
*  ~EOLN - Check for end of line
*
*  Inputs:
*	filePtr - pointer to file buffer variable
*
*  Outputs:
*	result - end of line flag
*
****************************************************************
*
~EOLN	start
	longa on
	longi on
	using ~FileCom
filePtr	equ	4

	tsc		set up direct page
	phd
	tcd
	sub4	filePtr,#~flHeader	point to file variable, not buffer
	ldy	#~flKind	error if file is not open
	lda	[filePtr],Y
	bne	lb1
	error #2	(unopened file)
	lda	#0
	bra	lb3
lb1	ldy	#~flEOF	error if at EOF
	lda	[filePtr],Y
	beq	lb2
	error #6	(EOLN while at end of file)
lb2	ldy	#~flEOLN	set EOLN
	lda	[filePtr],Y
lb3	tay
	lda	2	remove extra word from stack
	sta	6	 and reset DP
	lda	0
	sta	4
	pld
	pla
	pla
	tya
	rtl
	end

****************************************************************
*
*  ~EOLNStdIn - Check for end of line on standard in
*
*  Outputs:
*	result - end of line flag
*
****************************************************************
*
~EOLNStdIn start
	longa on
	longi on

	lda	~EOLNInput
	rtl
	end

****************************************************************
*
*  ~EquString - Test strings for equality
*
*  Inputs:
*	1,S - return address
*	4,S - length of string 2
*	6,S - pointer to string 2
*	10,S - length of string 1
*	12,S - pointer to string 1
*
*  Outputs:
*	A - 1 if equal, else 0
*	Z - 0 if equal, else 1
*
****************************************************************
*
~EquString start
	longa on
	longi on
return	equ	3	return address
length2	equ	6	length of string 2
s2	equ	8	ptr to string 2
length1	equ	12	length of string 1
s1	equ	14	ptr to string 1

	phd		save old dp
	tsc		set up local dp
	tcd

	ph4	s1	convert string 1 to standard form
	ph2	length1
	jsr	~StringToStandard
	pl2	length1
	pl4	s1
	ph4	s2	convert string 2 to standard form
	ph2	length2
	jsr	~StringToStandard
	pl2	length2
	pl4	s2
	lda	length1	check for length = 0 or -1
	ora	length2
	beq	equal
	lda	length1	normal case: strlen(string1) and
	cmp	length2	  strlen(string2) > 1
	bne	nequal
	ldx	length2
	ldy	#0	loop for string check
	short M
eq2	lda	[s1],Y
	cmp	[s2],Y
	bne	eq3
	iny
	dex
	bne	eq2
eq3	long	M
	beq	equal

nequal	ldx	#0	strings are not equal
	bra	rts
equal	ldx	#1	strings are equal

rts	lda	return-1	fix stack
	sta	s1
	lda	return+1
	sta	s1+2
	pld
	tsc
	clc
	adc	#12
	tcs
	txa		set return value
	rtl
	end

****************************************************************
*
*  ~Get - read a variable from the file
*
*  Inputs:
*	1,S - return address
*	4,S - pointer to file buffer
*
****************************************************************
*
~Get	start
	longa on
	longi on
	using ~FileCom

	sub	(4:filePtr),0

	sub4	filePtr,#~flHeader	change from buffer pointer to
!			 file variable pointer
	ph4	filePtr	read the next character
	jsl	~GetBuffer
	return
	end

****************************************************************
*
*  ~GetBuffer - read one file buffer from a disk file
*
*  Inputs:
*	1,S - return address
*	4,S - pointer to file buffer
*
****************************************************************
*
~GetBuffer start
	longa on
	longi on
	using ~FileCom

	sub	(4:filePtr),0
	phb
	phk
	plb
	ldy	#~flKind	error if file is not open
	lda	[filePtr],Y
	bne	gb0
	error #2	(file is not open)
	brl	gb6

gb0	ldy	#~flEOF	if EOF then
	lda	[filePtr],Y
	beq	gb1
	error #3	(read while at end of file)
	brl	gb6
gb1	anop		endif
	ldy	#~flRef	set the file reference number
	lda	[filePtr],Y
	sta	rdRef
	sta	efRef
	sta	mkRef
	ldy	#2	set the read length
	lda	[filePtr]
	sta	rdLen
	lda	[filePtr],Y
	sta	rdLen+2
	add4	filePtr,#~flHeader,rdBuff set the read address
	ldy	#~flKind	if text file then
	lda	[filePtr],Y
	and	#4
	beq	gb2
	ldy	#~flEOLN	  clear end of line flag
	lda	#0
	sta	[filePtr],Y
	jsr	CheckForEOF	  see if the last char read was eof
	ldy	#~flEOF	  if not already at EOF then begin
	lda	[filePtr],Y
	bne	tx1
	lda	#1	    read length is 1
	sta	rdLen
	jsr	Read	    read the next character
tx1	anop		  endif
	ldy	#~flHeader	  if character is a RETURN then
	lda	[filePtr],Y
	cmp	#$000D
	bne	tx3
	lda	#' '	    fake a space
	sta	[filePtr],Y
	ldy	#~flEOLN	    eoln = true
	lda	#1
	sta	[filePtr],Y
tx3	bra	gb6	  endif
gb2	anop		else {not text}
	jsr	CheckForEOF	  check for eof
	jsr	Read	  read the variable
gb6	anop		endif
	plb
	return
;
;  Check to see if we are at the end of the file
;
CheckForEOF Get_EOF efDCB	if eof(f) = mark(f) then
	Get_Mark mkDCB
	lda	efEOF
	cmp	mkMark
	bne	cf1
	lda	efEOF+2
	cmp	mkMark+2
	bne	cf1
	ldy	#~flEOF	  set EOF flag
	lda	#1
	sta	[filePtr],Y
cf1	rts
;
;  Read the next file variable
;
Read	read	rdDCB	read the variable
	bcc	rd1	if error then
	cmp	#$4C	  (read at eof is OK - will be detected
	beq	rd1	   elsewhere if it is really an error)
	error #4	  (I/O error)
rd1	rts		endif
;
;  Local data
;
rdDCB	anop		Read DCB
rdRef	ds	2
rdBuff	ds	4
rdLen	ds	4
	ds	4

efDCB	anop		GetEOF DCB
efRef	ds	2
efEOF	ds	4

mkDCB	anop		GetMark DCB
mkRef	ds	2
mkMark	ds	4
	end

****************************************************************
*
*  ~GeqString - Test strings s1 >= s2
*
*  Inputs:
*	1,S - return address
*	4,S - length of string 2
*	6,S - pointer to string 2
*	10,S - length of string 1
*	12,S - pointer to string 1
*
*  Outputs:
*	A - 1 if S1 >= S2, else 0
*	Z - 0 if S1 >= S2, else 1
*
****************************************************************
*
~GeqString start
	longa on
	longi on
return	equ	3	return address
length2	equ	6	length of string 2
s2	equ	8	ptr to string 2
length1	equ	12	length of string 1
s1	equ	14	ptr to string 1

	phd		save old dp
	tsc		set up local dp
	tcd

	ph4	s1	convert string 1 to standard form
	ph2	length1
	jsr	~StringToStandard
	pl2	length1
	pl4	s1
	ph4	s2	convert string 2 to standard form
	ph2	length2
	jsr	~StringToStandard
	pl2	length2
	pl4	s2
	lda	length1	check for length = 1
	ora	length2
	bmi	spcs1
	lda	length1	normal case: strlen(string1) and
	cmp	length2	  strlen(string2) > 1
	blt	ge1
	lda	length2

ge1	tax		branch is string is not 0
	bne	ge1b
	ldy	length1	if length 1 is not 0 then length2 is 0
	bne	true	  and length1 must be >= length2
	lda	[s2]	else string2 must be null
	and	#$00FF
	beq	true
	bra	false

ge1b	ldy	#0	check the string
	short M
ge2	lda	[s1],Y
	cmp	[s2],Y
	bne	ge3
	lda	[s1],Y
	beq	ge4
	iny
	dex
	bne	ge2
	long	M	strings are possibly equal
	lda	length1	if length1 >= length2 then test passes
	cmp	length2
	bge	true
	ldy	length1	else if s1(length2) = 0
	lda	[s2],Y	  test passes
	and	#$00FF
	beq	true
	bra	false	else test fails

ge3	long	M	strings are not equal go do test
	bra	spcs4
ge4	long	M	test fails because strings are equal
	bra	false

spcs1	lda	length1	split up special cases
	and	length2
	bpl	spcs2
	lda	s1+2	special case 1: strlen(string1) and
	cmp	s2+2	  strlen(string2) = 1
	bra	spcs4
spcs2	lda	length2
	bmi	spcs3
	lda	s1+2	special case 2: strlen(string1) = 1
	cmp	[s2]
	bra	spcs4
spcs3	lda	[s1]	special case 3: strlen(string2) = 1
	cmp	s2+2
spcs4	bge	true

false	ldx	#0	S1 < S2
	bra	rts
true	ldx	#1	S1 >= S2

rts	lda	return-1	fix stack
	sta	s1
	lda	return+1
	sta	s1+2
	pld
	tsc
	clc
	adc	#12
	tcs
	txa		set return value
	rtl
	end

****************************************************************
*
*  ~GrtString - Test strings s1 > s2
*
*  Inputs:
*	1,S - return address
*	4,S - length of string 2
*	6,S - pointer to string 2
*	10,S - length of string 1
*	12,S - pointer to string 1
*
*  Outputs:
*	A - 1 if S1 > S2, else 0
*	Z - 0 if S1 > S2, else 1
*
****************************************************************
*
~GrtString start
	longa on
	longi on
return	equ	3	return address
length2	equ	6	length of string 2
s2	equ	8	ptr to string 2
length1	equ	12	length of string 1
s1	equ	14	ptr to string 1

	phd		save old dp
	tsc		set up local dp
	tcd

	ph4	s1	convert string 1 to standard form
	ph2	length1
	jsr	~StringToStandard
	pl2	length1
	pl4	s1
	ph4	s2	convert string 2 to standard form
	ph2	length2
	jsr	~StringToStandard
	pl2	length2
	pl4	s2
	lda	length1	check for length = 1
	ora	length2
	bmi	spcs1
	lda	length1	normal case: strlen(string1) and
	cmp	length2	  strlen(string2) > 1
	blt	gt1
	lda	length2

gt1	tax		branch is string is not 0
	bne	gt1b
	ldy	length1	if length 1 is 0 not possible to be
	beq	false	  greater than S2
	lda	[s1]	else if anything in s1 then true
	and	#$00FF
	beq	false
	bra	true

gt1b	ldy	#0	check the string
	short M
gt2	lda	[s1],Y
	cmp	[s2],Y
	bne	gt3
	lda	[s1],Y
	beq	gt4
	iny
	dex
	bne	gt2
	long	M	strings are possibly equal
	lda	length1	if length are equal then strings are
	cmp	length2	  equal and test fails
	ble	false
	ldy	length2
	lda	[s1],Y
	and	#$00FF
	bne	true
	bra	false

gt3	long	M	strings are not equal go do test
	bra	spcs4
gt4	long	M	test fails because strings are equal
	bra	false

spcs1	lda	length1	split up special cases
	and	length2
	bpl	spcs2
	lda	s1+2	special case 1: strlen(string1) and
	cmp	s2+2	  strlen(string2) = 1
	bra	spcs4
spcs2	lda	length2
	bmi	spcs3
	lda	s1+2	special case 2: strlen(string1) = 1
	cmp	[s2]
	bra	spcs4
spcs3	lda	[s1]	special case 3: strlen(string2) = 1
	cmp	s2+2
spcs4	bgt	true

false	ldx	#0	S1 <= S2
	bra	rts
true	ldx	#1	S1 > S2

rts	lda	return-1	fix stack
	sta	s1
	lda	return+1
	sta	s1+2
	pld
	tsc
	clc
	adc	#12
	tcs
	txa		set return value
	rtl
	end

****************************************************************
*
*  ~Insert - insert a string into a string
*
*  Inputs:
*	1,S - return address
*	4,S - insert point
*	6,S - maximum length of string to insert
*	8,S - address of string to insert
*	12,S - maximum length of string to insert into
*	14,S - address of string to insert into
*
****************************************************************
*
~Insert	start
	longa on
	longi on
ttLen	equ	0	true length of target string
count	equ	2	temporary counter
sindx	equ	4	temp index of search string
tAddr1	equ	6	temp address
tAddr2	equ	10	temp address
otLen	equ	14	original length of target string

	sub	(2:index,2:tLen,4:tAddr,2:sLen,4:sAddr),16

	ph4	sAddr	get the true length of source string
	ph2	sLen
	jsr	~StringToStandard
	pl2	sLen
	pl4	sAddr

al1	ph4	tAddr	get the true length of target string
	ph2	tLen
	jsr	~StringToStandard
	pl2	ttLen
	pl4	tAddr
	lda	tLen	save the original length of the target
	sta	otLen	 string
	bpl	al2	if string has a length byte, correct
	eor	#$FFFF	 the max length
	inc	a
	sta	tLen

al2	lda	index	if index is beyond end of string
	cmp	tLen	  then adjust index to one passed
	ble	in1	  end of string so that we can blank
	lda	tlen	  fill the string
	inc	a
	sta	index
in1	lda	index	see if we have to move the string
	cmp	ttlen
	ble	in5
;
;  Here we don't have to move the string (insert at or beyond end of string)
;
	sec		fill with blanks up to index
	sbc	ttlen
	dec	a
	ldy	ttlen
	tax
	beq	in3
	short M
	lda	#' '
in2	sta	[tAddr],Y
	iny
	dex
	bne	in2
	long	M

in3	dec	index	adjust index to 0
	cpy	tLen	if filled to end of string there is no
	jge	in10	  room for source string so we are done
	clc		truncate source string if necessary
	lda	index	if index + stLen > tLen
	adc	sLen
	cmp	tLen
	ble	in9
	sec		  then sLen = tLen - index
	lda	tlen
	sbc	index
	sta	sLen
	bra	in9
;
;  Here we have to move part of the target string (insert in the string)
;
in5	dec	index	adjust index to 0
	clc		handle case where we don't move
	lda	index	  anything because source string + index
	adc	sLen	  is >= the max string length
	cmp	tLen
	blt	in6
	sec		  then sLen = tLen - index
	lda	tlen
	sbc	index
	sta	sLen
	bra	in9

in6	clc		from location = index
	lda	sLen	to location = index + sLen
	adc	index
	sta	sindx
	sec		count = ttLen - index
	lda	ttLen
	sbc	index
	sta	count
	clc		if count + to location > tLen
	adc	sindx
	cmp	tlen
	ble	in7
	sec
	lda	tLen
	sbc	sindx
	sta	count
in7	clc		compute from pointer
	lda	tAddr
	adc	index
	sta	tAddr1
	lda	#0
	adc	tAddr+2
	sta	tAddr1+2
	clc
	lda	tAddr
	adc	sindx
	sta	tAddr2
	lda	#0
	adc	tAddr+2
	sta	tAddr2+2
	ldy	count
	beq	in9
	dey
	short M
in8	lda	[tAddr1],Y
	sta	[tAddr2],Y
	dey
	bpl	in8
	long	M
	lda	sindx
	pha
	jsr	~InCopy
	pla
	clc		compute new index
	adc	count
	sta	index
	bra	in10

in9	jsr	~InCopy	copy over the source string
in10	lda	otLen	if the string has a length byte then
	bpl	in11
	dec4	tAddr	  set address of length byte
	short M	  set the length
	lda	index
	sta	[tAddr]
	long	M
	bra	rts
in11	ldy	index
	cpy	tlen	if not at end of string then
	bge	rts
	short M	set the null terminator
	lda	#0
	sta	[tAddr],Y
	long	M

rts	return

;...............................................................
;
;  ~InCopy - copy source to destination
;
;  Inputs:
;	sLen - length of source string
;	sAddr - source string pointer
;	index - index to begin copy
;	tAddr - target string pointer
;...............................................................

~InCopy	ldy	sLen	do nothing if source length is 0
	beq	cp4

	clc		get to address
	lda	tAddr
	adc	index
	sta	tAddr1
	lda	#0
	adc	tAddr+2
	sta	tAddr1+2
	clc		update index
	lda	index
	adc	sLen
	sta	index

	tya		move one byte if the move length is odd
	lsr	a
	bcc	cp2
	short M
	lda	[sAddr]
	sta	[tAddr1]
	long	M
	inc4	sAddr
	inc4	tAddr1
	dey
	beq	cp4

cp2	dey		move the bytes
	dey
cp3	lda	[sAddr],Y
	sta	[tAddr1],Y
	dey
	dey
	bpl	cp3
cp4	rts
	end

****************************************************************
*
*  ~IntChk - check for integer math error
*
*  Inputs:
*	A - value to check
*	V - set for error
*
****************************************************************
*
~IntChk	start

	php		save status
	bvs	err	branch if error
	cmp	#$8000
	bne	lb1
err	pha
	phx
	phy
	error #9	integer math error
	ply
	plx
	pla
lb1	plp
	rtl
	end

****************************************************************
*
*  ~IntToSet - convert an integer range into a set
*
*  Inputs:
*	6,S - start value
*	4,S - end value
*
*  Outputs:
*	set on stack
*
****************************************************************
*
~IntToSet start
	longa on
	longi on
	using ~SetCom

	phb		set data bank
	phk
	plb
	pl4	returnSet2	save return address
	lda	#2	set the size of the set
	sta	setSize
	move	#0,leftSet,#maxSet	initialize the set
	pla		get the right value
;
;  Handle single value sets
;
	cmp	#$8000
	bne	rg1
	pla
	bmi	err	if negative, error
	cmp	#maxSet*8	if bigger than largest element, no
	bge	err
	jsr	setbit
	bra	lb2
;
;  Handle set ranges
;
rg1	tax		error if < 0
	bmi	err2
	cmp	#maxset*8	...or too big
	bge	err2
	plx
	phx
	bmi	err
	cmp	1,s
	blt	rg3
rg2	jsr	setbit	set the bits
	cmp	1,s
	beq	rg3
	dec	a
	bpl	rg2
	bra	err2
rg3	pla
;
;  return
;
lb2	ph4	#leftSet	place the set on the stack
	ph2	setSize
	jsl	~LoadSet
	bra	lb3
err2	pla
err	error #7	set overflow
	ph2	#0
lb3	ph4	returnSet2	return
	plb
	rtl
;
;  Set a bit in the output set
;
setbit	pha		save the value
	tay
	and	#$0007	set the bit number
	tax
	tya		set the byte number
	lsr	A
	lsr	A
	lsr	A
	tay
	sec		compute the bit mask
	lda	#0
sb1	rol	A
	dex
	bpl	sb1
	ora	leftSet,Y	set the bit
	sta	leftSet,Y
	iny		set the size
	cpy	setSize
	blt	sb2
	sty	setSize
sb2	pla
	rts
	end

****************************************************************
*
*  ~IsDevice - see if a file name is a device name
*
*  Inputs:
*	ptr - file name pointer
*
*  Outputs:
*	C - set for a device, else clear
*
****************************************************************
*
~IsDevice private
ptr	equ	5	pointer to p-string

	phd		establish addressing
	tsc
	tcd
	lda	[ptr]	device names are at least 2 chars long
	and	#$00FF
	cmp	#2
	blt	lb1
	ldy	#1	device names start with '.'
	lda	[ptr],Y
	and	#$00FF
	cmp	#'.'
	bne	lb1
	iny		device names have a letter first
	lda	[ptr],Y
	and	#$005F
	cmp	#'A'
	blt	lb1
	cmp	#'Z'+1
	bge	lb1
	sec		it is a device name
	bra	lb2

lb1	clc		it is not a device name

lb2	pld		return
	pla
	plx
	plx
	pha
	rts
	end

****************************************************************
*
*  ~Length - find the length of a string
*
*  Inputs:
*	1,S - return address
*	4,S - length of the string
*	6,S - pointer to the string
*
*  Outputs:
*	A - length of string
*	Z - 0 if length = 0 else 1
*
****************************************************************
*
~Length	start
	longa on
	longi on
return	equ	3	return address
len	equ	6	length of string
ptr	equ	8	ptr to string

	phd		save old dp
	tsc		set up local dp
	tcd

	ldy	#0
	lda	len	check for a character
	bpl	ln1
	cmp	#-1
	bne	ls1
	ldy	#1	if character is not null
	lda	ptr+2
	bne	rts	  length = 1
	dey
	bra	rts	else length = 0

ls1	lda	[ptr]	string has a length byte - return
	and	#$00FF	 that value
	tay
	bra	rts

ln1	beq	rts
	short M
ln2	lda	[ptr],Y
	beq	ln3
	iny
	cpy	len
	blt	ln2
ln3	long	M

rts	lda	return-1	fix stack
	sta	ptr
	lda	return+1
	sta	ptr+2
	pld
	tsc
	clc
	adc	#6
	tcs
	tya		set return value
	rtl
	end

****************************************************************
*
*  ~LoadSet - Move a set from a memory location to the stack
*
*  Inputs:
*	1,S - return address
*	4,S - length of the set to load
*	6,S - address to load set from
*
****************************************************************
*
~LoadSet start

	phb		set the bank
	phk
	plb
	pl4	rtAddr	save the return address
	plx		fetch the set length
	txy		save the length
	lda	1,S	set up the set load addresses
	sta	ld1+1
	sta	ld2+1
	lda	2,S
	sta	ld1+2
	sta	ld2+2
	pla
	pla
	txa		if the set is an odd length, push last
	lsr	a	 byte
	bcc	lb0
	dex
	short M
ld1	lda	>ld1,X
	pha
	long	M
lb0	dex		move the set to the stack
	dex
	bmi	lb2
lb1	anop
ld2	lda	>ld2,X
	pha
	dex
	dex
	bpl	lb1
lb2	phy		place the length on the stack
	ph4	rtAddr	return
	plb
	rtl

rtAddr	ds	4	return address
	end

****************************************************************
*
*  ~MoveString - move a string
*
*  Inputs:
*	1,S - return address
*	4,S - source length
*	6,S - source address
*	10,S - destination length
*	12,S - destination address
*
****************************************************************
*
~MoveString start
	longa on
	longi on
len	equ	0	# bytes to move
lAddr	equ	2	address of length byte in length string 

	sub	(2:sLen,4:sAddr,2:dLen,4:dAddr),6

	lda	sLen	if strings have the same form then
	cmp	dLen
	bne	mv0
	ph4	dAddr
	ph4	sAddr
	lda	sLen
	bpl	mm1
	eor	#$FFFF
	inc	a
	inc	a
mm1	pha
	jsl	~Move
	bra	mv8

mv0	ph4	sAddr	convert to standard format
	ph2	sLen
	jsr	~StringToStandard
	pl2	sLen
	pl4	sAddr
	move4 dAddr,lAddr	save (possible) addr of length byte

mv1	lda	dLen	if slen >= dlen
	bpl	mv2	  length = dlen
	eor	#$FFFF	else
	inc	a	  length = slen
	inc4	dAddr	 (if dest has a length byte, go past it)
mv2	cmp	sLen
	blt	mv3
	lda	sLen

mv3	tay		move one byte if the move length is odd
	sta	len
	beq	mv6
	lsr	a
	bcc	mv4
	short M
	lda	[sAddr]
	sta	[dAddr]
	long	M
	inc4	sAddr
	inc4	dAddr
	dey
	beq	mv6

mv4	dey		move the bytes
	dey
mv5	lda	[sAddr],Y
	sta	[dAddr],Y
	dey
	dey
	bpl	mv5

mv6	ldy	dLen	if dest string has a length byte,
	bpl	mv7	 set it
	short M
	lda	len
	sta	[lAddr]
	long	M
	bra	mv8	else
mv7	ldy	len	  if dest string is longer than source
	cpy	dLen	  string, set the nul terminator
	bge	mv8
	short M
	lda	#0
	sta	[lAddr],Y
	long	M
mv8	return
	end

****************************************************************
*
*  ~NewFile - Create a new file entry
*
*  Inputs:
*	1,S - return address
*	4,S - address to place the pointer to the file buffer
*	8,S - # bytes in buffer
*
****************************************************************
*
~NewFile start
	longa on
	longi on
	using ~FileCom
buff	equ	0	pointer to file buffer

	sub	(4:ptr,2:size),4
	phb
	phk
	plb
;
;  Push the current file
;
	ph4	#8	allocate space for a file record
	jsl	~New
	sta	buff
	stx	buff+2
	ldy	#2	save the file buffer pointer
	lda	~thisFile
	sta	[buff]
	lda	~thisFile+2
	sta	[buff],Y
	ldy	#4	save the old file buffer
	lda	~fileBuff
	sta	[buff],Y
	ldy	#6
	lda	~fileBuff+2
	sta	[buff],Y
	move4 buff,~fileBuff	set the file buffer pointer
;
;  Allocate a file variable
;
	clc		allocate the memory - true size is
	lda	size	  buffer size plus header size
	cmp	#2
	bge	lb0
	lda	#2
lb0	ldx	#0
	adc	#~flHeader
	bcc	lb1
	inx
lb1	phx
	pha
	jsl	~New
	sta	buff
	sta	~thisFile
	stx	buff+2
	stx	~thisFile+2
	ora	buff+2
	beq	err
	lda	size	set file attributes:
	sta	[buff]	  size of i/o buffer
	lda	#0
	ldy	#2
	sta	[buff],Y
	ldy	#~flHeader	  zero high word of size, ProDOS ref #,
	lda	#0	    open kind, pointer to name,
lb2	sta	[buff],Y	    1st 2 bytes of file buffer
	dey
	dey
	bne	lb2
	clc		set pointer to file buffer
	lda	buff
	adc	#~flHeader
	sta	[ptr]
	lda	buff+2
	adc	#0
	ldy	#2
	sta	[ptr],Y
lb3	plb
	return

err	error #5	out of memory
	bra	lb3
	end

****************************************************************
*
*  ~NewOpenRec - create a new open record
*
*  Inputs:
*	~thisFile - current open file pointer
*	~fileBuff - chain to other open files
*	~fileRecBuff - pointer to previous file info record
*
*  Outputs:
*	~fileRecBuff - pointer to old file info record
*
****************************************************************
*
~NewOpenRec start
	using ~FileCom
ptr	equ	3	location of local pointer

	phb		use local data bank
	phk
	plb
	ph4	#12	reserve 12 bytes
	jsl	~New
	phx		save the pointer
	pha
	phd		set up a local DP
	tsc
	tcd
	lda	~thisFile	save thisFile
	sta	[ptr]
	ldy	#2
	lda	~thisFile+2
	sta	[ptr],Y
	lda	~fileBuff	save ~fileBuff
	ldy	#4
	sta	[ptr],Y
	lda	~fileBuff+2
	ldy	#6
	sta	[ptr],Y
	lda	~fileRecBuff	save ~fileRecBuff
	ldy	#8
	sta	[ptr],Y
	lda	~fileRecBuff+2
	ldy	#10
	sta	[ptr],Y
	pld		reset DP
	pla		save new ~fileRecBuff
	sta	~fileRecBuff
	pla
	sta	~fileRecBuff+2
	stz	~thisFile	zero file chain
	stz	~thisFile+2
	stz	~fileBuff	zero file buffer
	stz	~fileBuff+2
	plb		restore data bank
	rtl
	end

****************************************************************
*
*  ~Open - Open a file
*
*  Inputs:
*	strlen - length of the string buffer
*	strptr - pointer to the string buffer (nil for no name)
*	filePtr - pointer to the file buffer
*	kind - open type:
*		1 - input
*		2 - output
*		5 - text input
*		6 - text output
*
****************************************************************
*
~Open	start
	longa on
	longi on
maxNameLength equ 65	max length of a file name
return	equ	13	RETURN key code

ptr	equ	7	work pointer
coutptr	equ	3	pointer for use in calls to ~COut
	using ~FileCom

	sub	(2:strLen,4:strPtr,2:size,2:kind,4:filePtr),11
	phb
	phk
	plb
;
;  Convert the string to standard form
;
	ph4	strPtr	  convert string to standard form
	ph2	strLen
	jsr	~StringToStandard
	pl2	strLen
	pl4	strPtr
;
;  If there is no file variable, allocate one
;
	lda	[filePtr]	if no file buffer then
	ldy	#2
	ora	[filePtr],Y
	bne	af1
	ph2	size	  allocate one
	ph4	filePtr
	jsl	~NewFile
af1	anop		endif
;
;  Set up the pointers
;
	ldy	#2	save buffer ptr for calls to ~COut
	lda	[filePtr]	point to file variable, not buffer
	sta	cOutPtr
	lda	[filePtr],Y
	sta	cOutPtr+2
	sub4	cOutPtr,#~flHeader,filePtr
;
;  If a file is already open, reset or rewrite it.
;
	ldy	#~flKind	if file is open then
	lda	[filePtr],Y
	beq	fl1
	and	#6	  if open for text output then
	cmp	#6
	bne	rt2
	ldy	#~flEOLN	    if the last char was not a return
	lda	[filePtr],Y	      then
	bne	rt1
	lda	#return	      writeln
	jsl	~_COut
rt1	anop		    endif
rt2	anop		  endif
	ldy	#~flRef	  save reference number
	lda	[filePtr],Y
	sta	dcbRef
	sta	clRef
	lda	strLen	  if a new name has been assigned then
	beq	mm0
	close clDCB	    close the old file
	bra	fl1	    goto open file code
mm0	anop		  endif
	lda	kind	  if reseting the file then
	lsr	A
	bcc	mm1
	Set_Mark DCB	    set mark to 0
	bra	mm2	  else
mm1	Set_EOF DCB	    set eof to 0
mm2	anop		  endif
	brl	fl9	else
;
;  If there is no file, open one
;
fl1	lda	strLen	  if no name is provided and
	ldy	#~flName	    no old name exists then
	ora	[filePtr],Y
	iny
	iny
	ora	[filePtr],Y
	bne	fl5
	Get_Prefix gpDCB	    get work prefix
	jcs	proErr
	lla	strPtr,name+1	    {set a system default name}
	short I,M	    increment the system default file #
	ldx	defaultName
fl3	inc	defaultName,X
	lda	defaultName,X
	cmp	#'9'+1
	bne	fl4
	lda	#'0'
	sta	defaultName,X
	dex
	bra	fl3
fl4	ldx	name	    append name to work prefix
	ldy	#1
	lda	#'/'
	cmp	name,X
	beq	fl4a
	inx
	sta	name,X
fl4a	lda	defaultName,Y
	inx
	sta	name,X
	cpx	#maxNameLength
	bge	fl4b
	iny
	cpy	defaultName
	ble	fl4a
fl4b	long	I,M
	txa
	and	#$00FF
	sta	strLen
	bra	fl5b	    set the file name
fl5	lda	strLen	  else if a file name is provided then
	beq	dn1
	ldy	#~flName	    if an old name exists then
	lda	[filePtr],Y
	tax
	iny
	iny
	ora	[filePtr],Y
	beq	fl5b
	lda	[filePtr],Y	      dispose of it
	sta	ptr+2
	stx	ptr
	dispose ptr
fl5b	new	ptr,#maxNameLength	      set the file name
	ldy	#~flName
	lda	ptr
	sta	[filePtr],Y
	lda	ptr+2
	iny
	iny
	sta	[filePtr],Y
	short M
	ldy	#0
sn1	lda	[strPtr],Y
	sta	[ptr],Y
	sta	name+1,Y
	beq	sn2
	cmp	#' '
	beq	sn2
	iny
	cpy	strLen
	bge	sn2
	cpy	#maxNameLength
	blt	sn1
sn2	tya
	sta	name
	long	M
	tya
	ldy	#~flNameLen
	sta	[filePtr],Y
	bra	dn4	    else
dn1	ldy	#~flName	      recover old file name
	lda	[filePtr],Y
	sta	ptr
	ldy	#~flName+2
	lda	[filePtr],Y
	sta	ptr+2
	ldy	#~flNameLen
	lda	[filePtr],Y
	tay
	short M
	sta	name
	dey
	beq	dn3
dn2	lda	[ptr],Y
	sta	name+1,Y
	dey
	bpl	dn2
dn3	long	M
dn4	anop		    endif
	lla	opName,name	  set addr of file name
	lda	kind	  if opening for output then
	lsr	A
	lsr	A
	bcc	fl7
	move4 opName,giName	    if file exists then
	Get_File_Info giDCB
	bcs	fl6
	lda	kind	      if opening for input then
	lsr	A
	bcs	fl7		 skip creating file
	move4 opName,dsName	      delete it
	Destroy dsDCB
	jcs	proErr
fl6	anop		    endif
	lda	kind	    if opening a text file then
	and	#4	      set file type to TXT
	bne	fl6a	    else
	lda	#6	      set file type to BIN
fl6a	sta	crType	    endif
	ph4	opName	    if the name is not a device then
	jsr	~IsDevice
	bcs	fl7
	move4 opName,crName	      create the file
	create crDCB
	jcs	proErr
fl7	anop		  endif
	ldy	#~flRef	  if file is not open then
	lda	[filePtr],Y
	bne	fl8
	ph4	opName	    if the name is not a device then
	jsr	~IsDevice
	bcs	fl7a
	move4 opName,exName	      expand devices
	Expand_Device exDCB
fl7a	open	opDCB	    open the file
	bcs	proErr
	ldy	#~flRef	    save the file reference number
	lda	opRef
	sta	[filePtr],Y
fl8	anop		  endif
fl9	anop		endif
;
;  Initialize the file.
;
	ldy	#~flKind	set the file kind
	lda	kind
	sta	[filePtr],Y
	lda	kind	if opening for input
	lsr	A
	bcc	if1
	lsr	A	  and not opening for output then
	bcs	if1
	ldy	#~flEOLN	  eoln = false
	lda	#0
	sta	[filePtr],Y
	ldy	#~flEOF	  eof = false
	sta	[filePtr],Y
	ph4	filePtr	  do the initial read
	jsl	~GetBuffer
!			  endif
	bra	if2	else
if1	ldy	#~flEOLN	  eoln := true
	lda	#1
	sta	[filePtr],Y
	ldy	#~flEOF	  eof := true
	sta	[filePtr],Y
if2	anop		endif
if3	plb
	return

proErr	error #4	I/O error
	bra	if3
;
;  Local data areas
;
opDCB	anop		DCB for OPEN
opRef	ds	2
opName	ds	4
opBuff	ds	4

giDCB	anop		DCB for GET_FILE_INFO
giName	ds	4
	ds	22

dsDCB	anop		DCB for DESTROY
dsName	ds	4

crDCB	anop		DCB for CREATE
crName	ds	4	name
	dc	i'$C3'	access
crType	ds	2	file type
	dc	i4'0'	aux type
	dc	i'1'	file kind
	dc	i4'0'	create date/time

clDCB	anop		DCB for CLOSE
clRef	ds	2

gpDCB	anop		get prefix DCB
gpPrefixNum dc i'3'	(used to get work prefix)
gpPrefix dc	a4'name'

defaultName dw SYSPAS0000
name	ds	maxNameLength+2

DCB	anop		DCB for SET_MARK, SET_EOF
DCBRef	ds	2
	dc	i4'0'	position

exDCB	anop		expand device DCB
exName	ds	4	  pointer to name
	end

****************************************************************
*
*  ~Pack - Pack an array
*
*  Inputs:
*	upAddr - addess of unpacked array
*	upSize - size of elements in unpacked array
*	upEls - # elements in unpacked array
*	start - starting index for move
*	pkAddr - address of packed array
*	pkSize - size of elements in packed array
*	pkEls - # elements in packed array
*
****************************************************************
*
~Pack	start
	sub	(2:pkEls,2:pkSize,4:pkAddr,2:start,2:upEls,2:upSize,4:upAddr),0

	sec		make sure there are enough elements
	lda	upEls
	sbc	start
	cmp	pkEls
	bge	lb1
	error #1	subrange exceeded
	bra	lb4

lb1	ldx	upSize	set start of unpacked array
	lda	start
	jsl	~mul2
	clc
	adc	upAddr
	sta	upAddr
	bcc	lb1a
	inc	upAddr+2
lb1a	lda	upSize	if elements are of the same size then
	cmp	pkSize
	bne	lb2
	ph4	pkAddr	  use ~move to move elements
	ph4	upAddr
	lda	pkEls
	ldx	pkSize
	jsl	~mul2
	pha
	jsl	~move
	bra	lb4	else
lb2	ldx	pkEls	  while pkEls > 0 do begin
	beq	lb4
lb3	short M	    pkAddr^ := upAddr^;
	lda	[upAddr]
	sta	[pkAddr]
	long	M
	inc4	pkAddr	    pkAddr := pkAddr+1;
	add4	upAddr,#2	    upAddr := upAddr+2;
	dex		    pkEls := pkEls-1;
	bne	lb3	    end;
lb4	return
	end

****************************************************************
*
*  ~Pack2 - Pack an array
*
*  Inputs:
*	upAddr - addess of unpacked array
*	upSize - size of elements in unpacked array
*	upEls - # elements in unpacked array
*	start - starting index for move
*	pkAddr - address of packed array
*	pkSize - size of elements in packed array
*	pkEls - # elements in packed array
*
****************************************************************
*
~Pack2	start

	sub	(4:pkEls,2:pkSize,4:pkAddr,4:start,4:upEls,2:upSize,4:upAddr),0

	sec		make sure there are enough elements
	lda	upEls
	sbc	start
	tax
	lda	upEls+2
	sbc	start+2
	cmp	pkEls+2
	bne	lb0
	cpx	pkEls
lb0	bge	lb1
	error #1	subrange exceeded
	bra	lb4

lb1	ph2	#0	set start of unpacked array
	ph2	upSize
	ph4	start
	jsl	~mul4
	clc
	pla
	adc	upAddr
	sta	upAddr
	pla
	adc	upAddr+2
	sta	upAddr+2
lb1a	lda	upSize	if elements are of the same size then
	cmp	pkSize
	bne	lb2
	ph4	pkAddr	  use ~move to move elements
	ph4	upAddr
	ph4	pkEls
	ph2	#0
	ph2	pkSize
	jsl	~Mul4
	jsl	~LongMove
	bra	lb4	else
lb2	lda	pkEls	  while pkEls > 0 do begin
	ora	pkEls+2
	beq	lb4
	short M	    pkAddr^ := upAddr^;
	lda	[upAddr]
	sta	[pkAddr]
	long	M
	inc4	pkAddr	    pkAddr := pkAddr+1;
	add4	upAddr,#2	    upAddr := upAddr+2;
	dec4	pkEls	    pkEls := pkEls-1;
	bra	lb2	    end;
lb4	return
	end

****************************************************************
*
*  ~Page - Write form feed
*
*  Inputs:
*	1,S - return address
*	4,S - address of output routine
*
****************************************************************
*
~Page	start
	longa on
	longi on
formFeed equ	12	form feed character

	sub	(4:outPut),0
	lda	#formFeed	print
	jsl	~_COut
	return
	end

****************************************************************
*
*  ~PMod4 - Four Byte Signed Integer Modulo Operation
*
*  Inputs:
*	NUM1 - denominator
*	NUM2 - numerator
*
*  Outputs:
*	ANS - result
*	V - set for division by zero
*
*  Notes
*	1) Uses ~DIV4, ~SIGN.
*
****************************************************************
*
~PMod4	start
n1	equ	14	first arg
n2	equ	7	second arg
n3	equ	3	result

	phx		place n2 in DP
	pha
	pea	0	n3 := 0;
	pea	0
	phd
	tsc
	tcd
	lda	n2+2	if n2 <= 0 then
	bmi	err	  error;
	ora	n2
	beq	err
	lda	n1+2	if n1 < 0 then begin
	bpl	lb1
	sec		  n3 := remainder(-n1 div n2);
	lda	#0
	sbc	n1
	sta	n1
	lda	#0
	sbc	n1+2
	sta	n1+2
	jsr	mod
	lda	n3	  if n3 <> 0 then
	ora	n3+2
	beq	lb2
	sub4	n2,n3,n3	    n3 := n2-n3;
	bra	lb2	  end
lb1	anop		else
	jsr	mod	  n3 := remainder(n1 div n2);
lb2	pld
	pla
	sta	10,s
	pla
	sta	10,s
	pla
	pla
	rtl

err	error #9	integer math error
	bra	lb2

mod	lda	n1+2	if n1 < 64K and n2 < 64K then
	ora	n2+2
	bne	md4
	lda	#0	  16 bit divide
	ldy	#16
md1	asl	n1
	rol	a
	sec
	sbc	n2
	bcs	md2
	adc	n2
md2	dey
	bne	md1
	sta	n3
	rts		else

md4	ldy	#32	  32 bit divide
md5	asl	n1
	rol	n1+2
	rol	n3
	rol	n3+2
	sec
	lda	n3
	sbc	n2
	tax
	lda	n3+2
	sbc	n2+2
	bcc	md6
	stx	n3
	sta	n3+2
md6	dey
	bne	md5
	rts
	end

****************************************************************
*
*  ~PNew - Allocate memory
*
*  Inputs:
*	1,S - return address
*	4,S - # bytes to allocate
*	6,S - address of pointer
*
****************************************************************
*
~PNew	start
	longa on
	longi on

	sub	(2:bytes,4:ptr),0

	ph2	#0
	ph2	bytes
	jsl	~New
	sta	[ptr]
	txa
	ldy	#2
	sta	[ptr],Y
	ora	[ptr]
	bne	lb1
	error #5	out of memory
lb1	return
	end

****************************************************************
*
*  ~PNew4 - Allocate memory
*
*  Inputs:
*	1,S - return address
*	4,S - # bytes to allocate
*	6,S - address of pointer
*
****************************************************************
*
~PNew4	start

	sub	(4:bytes,4:ptr),0

	ph4	bytes
	jsl	~New
	sta	[ptr]
	txa
	ldy	#2
	sta	[ptr],Y
	ora	[ptr]
	bne	lb1
	error #5	out of memory
lb1	return
	end

****************************************************************
*
*  ~Pos - find the position of a substring within a string
*
*  Inputs:
*	1,S - return address
*	4,S - target string maximum length
*	6,S - target string address
*	10,S - substring maximum length
*	12,S - substring pointer
*
*  Outputs:
*	A - length of string
*	Z - 0 if length = 0 else 1
*
****************************************************************
*
~Pos	start
	longa on
	longi on
index	equ	0	index of target string
count	equ	2	# of searches
tindx	equ	4	sub index of target string
sindx	equ	6	sub index of search string

	sub	(2:tlen,4:tAddr,2:slen,4:sAddr),8

	ph4	tAddr	convert target string to standard form
	ph2	tLen
	jsr	~StringToStandard
	pl2	tLen
	pl4	tAddr
	lda	tLen	if target string is null return 0
	beq	ps7

	ph4	sAddr	convert sub string to standard form
	ph2	sLen
	jsr	~StringToStandard
	pl2	sLen
	pl4	sAddr
	lda	sLen	not found if sub string is null
	beq	ps7
	cmp	tLen	if substring is > target then not found
	bgt	ps7

	stz	index	initialize index
	sec		compute number of searches
	lda	tLen
	sbc	sLen
	sta	count

ps4	lda	index
	sta	tindx
	stz	sindx
	short M

ps5	ldy	tindx	search for substring at index
	lda	[tAddr],Y
	iny
	sty	tindx
	ldy	sindx
	cmp	[sAddr],Y
	bne	ps6
	iny
	cpy	slen
	beq	ps8
	sty	sindx
	bra	ps5

ps6	long	M	next index
	inc	index
	dec	count
	bpl	ps4

ps7	ldx	#0	position is not found
	bra	rts

ps8	long	M	found the substring return the index
	ldx	index
	inx

rts	return 2	return answer in A and zero flag set	
	end

****************************************************************
*
*  ~ProDOS - make a ProDOS call
*
*  Inputs:
*	X-A - DCB address
*	Y - call number
*
*  Outputs:
*	~ToolError - error number
*
****************************************************************
*
~ProDOS	start
	longa on
	longi on

	sta	>DCB
	txa
	sta	>DCB+2
	tya
	sta	>callNum
	jsl	$E100A8
callNum	ds	2
DCB	ds	4
	sta	>~ToolError
	rtl
	end

****************************************************************
*
*  ~PSeed - Initialize the random number generator
*
*  Inputs:
*	1,S - return address
*	4,S - integer seed value
*
****************************************************************
*
~PSeed	start
	longa on
	longi on

	sub	(2:seedVal),0
	seed	seedVal
	return
	end

****************************************************************
*
*  ~Put - Write a file variable to the output file
*
*  Inputs:
*	1,S - return address
*	4,S - pointer to the file buffer
*
****************************************************************
*
~Put	start
	longa on
	longi on
	using ~FileCom
return	equ	13	RETURN key code

	sub	(4:filePtr),0
	phb		save the old data bank; use code bank
	phk
	plb

	sec		set write DCB file pointer and form
	lda	filePtr	 address of file record
	sta	wrBuff
	sbc	#~flHeader
	sta	filePtr
	lda	filePtr+2
	sta	wrBuff+2
	sbc	#0
	sta	filePtr+2
	ldy	#~flKind	if the file is open for text output then
	lda	[filePtr],Y
	and	#6
	cmp	#6
	bne	rt2
	ldy	#~flHeader	  if this is an eoln then
	lda	[filePtr],Y
	and	#$00FF
	cmp	#return
	bne	rt0
	lda	#1	    eoln := true
	bra	rt1	  else
rt0	lda	#0	    eoln := false
rt1	ldy	#~flEOLN	  endif
	sta	[filePtr],Y
rt2	anop		endif
	ldy	#~flRef	set the file reference number
	lda	[filePtr],Y
	sta	wrRef
	ldy	#~flLen	set the buffer length
	lda	[filePtr],Y
	sta	wrLen
	iny
	iny
	lda	[filePtr],Y
	sta	wrLen+2
	write wrDCB	write the block
	bcc	lb1
	error #4
lb1	plb		restore caller's data bank
	return

wrDCB	anop		write DCB
wrRef	ds	2	reference number
wrBuff	ds	4	data buffer
wrLen	ds	4	number of bytes to write
	ds	4	transfer count
	end

****************************************************************
*
*  ~PutB - Format a Boolean Variable
*
*  Inputs:
*	n - boolean value to write
*	f1 - field width
*	cr - carriage return flag
*	err - error output flag
*
****************************************************************
*
~PutB	start
	longa on
	longi on

	pha		make room on stack for addr of string
	pha
	tsc		move bytes down
	tax
	ldy	#4
lb1	lda	>4,X
	sta	>0,X
	inx
	inx
	dey
	bne	lb1
	lda	12,S	move field width
	sta	8,S
	lda	14,S	if printing true then
	beq	lb2
	lda	#true	  set lsw of true addr
	sta	12,S
	lda	#l:true	  set length of true string
	sta	10,S
	bra	lb3	else
lb2	lda	#false	  set lsw of false addr
	sta	12,S
	lda	#l:false	  set length of false string
	sta	10,S
lb3	lda	#^true	endif
	sta	14,S	set msw of string address
	brl	~PutSP	print the string

true	dc	c'true'
false	dc	c'false'
	end

****************************************************************
*
*  ~PutBoolean - Write boolean
*
*  Inputs:
*	n - boolean value to write
*	f1 - field width
*	file - pointer to file variable
*
****************************************************************
*
~PutBoolean start
	longa on
	longi on

	pha		make room on stack for addr of string
	pha
	tsc		move bytes down
	tax
	ldy	#4
lb1	lda	>4,X
	sta	>0,X
	inx
	inx
	dey
	bne	lb1
	lda	12,S	move field width
	sta	8,S
	lda	14,S	if printing true then
	beq	lb2
	lda	#true	  set lsw of true addr
	sta	12,S
	lda	#l:true	  set length of true string
	sta	10,S
	bra	lb3	else
lb2	lda	#false	  set lsw of false addr
	sta	12,S
	lda	#l:false	  set length of false string
	sta	10,S
lb3	lda	#^true	endif
	sta	14,S	set msw of string address
	brl	~WriteString	print the string

true	dc	c'true'
false	dc	c'false'
	end

****************************************************************
*
*  ~PutSP - Pascal string output to standard out
*
*  Inputs:
*	ADR - address of string to write
*	FW - field width
*	LN - length of string
*	CR - carriage return flag
*	ERR - error output flag
*
****************************************************************
*
~PutSP	start
	longa on
	longi on
adr	equ	12	address of string to write
ln	equ	10	length of string
fw	equ	8	field width
cr	equ	6	carriage return flag
err	equ	4	error output flag

	tsc		set up DP
	phd
	tcd
	ph4	adr	convert string to standard form
	ph2	ln
	jsr	~StringToStandard
	pl2	ln
	pl4	adr
	sec		A = - # lead blanks
	lda	fw	if fw <= 0 then
	beq	error	  flag error
	bpl	lb1
	cmp	#$8000
	beq	lb3
error	error #1
	bra	lb3
lb1	sbc	ln
	bmi	lb2	if A > 0 then
	beq	lb3
	ldy	err	  print A blanks
	jsl	~prbl
	bra	lb3	else if A < 0 then
lb2	lda	fw	  ln := fw
	sta	ln
lb3	anop		endif

	lda	err	print the string
	beq	lb5
	lda	ln
	beq	lb4a
lb4	lda	[adr]
	and	#$00FF
	pha
	jsl	SysCharErrout
	inc	adr
	dec	ln
	bne	lb4
lb4a	lda	cr
	beq	lb6
	ph2	#13
	jsl	SysCharErrout
	bra	lb6
lb5	lda	ln
	beq	lb5b
lb5a	lda	[adr]
	and	#$00FF
	pha
	jsl	SysCharOut
	inc	adr
	dec	ln
	bne	lb5a
lb5b	lda	cr
	beq	lb6
	ph2	#13
	jsl	SysCharOut
lb6	anop          

	move4 0,adr	patch return addr
	pld		fix DP
	clc		remove extra stack space
	tsc
	adc	#12
	tcs
	rtl
	end

****************************************************************
*
*  ~RandomI - Return a random integer and long integer
*
*  Outputs:
*	A - random integer
*	X - random integer
*
****************************************************************
*
~RandomI start
	longa on
	longi on

	jsl	~ranx	form the random bit pattern
	lda	>~seed+2	return a long value
	tax
	lda	>~seed
	rtl
	end

****************************************************************
*
*  ~ReadChar - Read a character
*
*  Inputs:
*	1,S - return address
*	4,S - pointer to file buffer
*
*  Outputs:
*	A - character read
*
****************************************************************
*
~ReadChar start
	longa on
	longi on
	using ~FileCom

	sub	(4:filePtr),0

	sub4	filePtr,#~flHeader	point to file variable, not buffer
	ldy	#~flHeader	get the next character
	lda	[filePtr],Y
	and	#$00FF
	pha		read the next character
	ph4	filePtr
	jsl	~GetBuffer
	plx

	return 2
	end

****************************************************************
*
*  ~ReadCMDLine - read the command line
*
*  Inputs:
*	1,S - return address
*	4,S - length of the string buffer
*	6,S - pointer to the string buffer
*
****************************************************************
*
~ReadCMDLine start
	longa on
	longi on
ptr	equ	0	work pointer
tLen	equ	4	original length of string

	sub	(2:slen,4:sptr),6
	phb
	phk
	plb

	ph4	sPtr	save the original length
	lda	sLen	convert string to standard form
	sta	tLen
	pha
	jsr	~StringToMaxStandard
	pl2	sLen
	pl4	sPtr
	add4	~commandLine,#8,ptr	skip the shell identifier
	ldy	#0	Y = length
	lda	~commandLine	quit if there is no string
	ora	~commandLine+2
	beq	lb5
	short M
lb3	cpy	sLen	while (Y < slen)
	bge	lb4
	lda	[ptr],Y	  and (ptr[Y] <> 0) do begin
	sta	[sptr],Y	  sptr[Y] := ptr[Y];
	beq	lb4
	iny		  Y := Y+1;
	bra	lb3	  end;
lb4	anop
lb5	long	M
	lda	tLen	if string has a length byte then
	bpl	lb6
	dec4	sPtr	  set it
	short M
	tya
	sta	[sPtr]
	long	M
lb6	plb
	return
	end

****************************************************************
*
*  ~ReadInt - Read an integer
*
*  Inputs:
*	filePtr - pointer to file buffer
*
*  Outputs:
*	A - value read
*
****************************************************************
*
~ReadInt start
	longa on
	longi on
	using ~FileCom
	using ~StringCom
tab	equ	9	TAB key code

	sub	(4:filePtr),0
	phb
	phk
	plb

	sub4	filePtr,#~flHeader	point to file variable, not buffer
lb1	ldy	#~flHeader	skip leading white space
	lda	[filePtr],Y
	and	#$00FF
	cmp	#tab
	beq	lb2
	cmp	#' '
	bne	lb3
lb2	ph4	filePtr
	jsl	~GetBuffer
	bra	lb1
lb3	stz	~stringLength	read the leading sign, if any
	cmp	#'+'
	beq	lb5
	cmp	#'-'
	bne	lb4
	sta	~string
	inc	~stringLength
	bra	lb5
lb4	cmp	#'0'	read the numbers in the string
	blt	lb6
	cmp	#'9'+1
	bge	lb6
	ldx	~stringLength
	sta	~string,X
	inc	~stringLength
	cpx	#78
	bge	lb7
lb5	ldy	#~flEOF
	lda	[filePtr],Y
	bne	lb6
	ph4	filePtr
	jsl	~GetBuffer
	ldy	#~flHeader
	lda	[filePtr],Y
	and	#$00FF
	bra	lb4
lb6	pha		convert the string into a number
	ph4	#~string
	ph2	~stringLength
	ph2	#1
	_Dec2Int
	bcc	lb8
lb7	error #1	subrange exceeded
lb8	plx
	plb

	return 2
	end

****************************************************************
*
*  ~ReadIntInput - Read an integer from standard in
*
*  Outputs:
*	A - value read
*
****************************************************************
*
~ReadIntInput start
	longa on
	longi on
	using ~StringCom
tab	equ	9	TAB key code

	phb
	phk
	plb

lb1	jsl	~GetCharInput	skip leading white space
	cmp	#tab
	beq	lb1
	cmp	#' '
	beq	lb1
	stz	~stringLength	read the leading sign, if any
	cmp	#'+'
	beq	lb5
	cmp	#'-'
	bne	lb4
	sta	~string
	inc	~stringLength
	bra	lb5
lb4	cmp	#'0'	read the numbers in the string
	blt	lb6
	cmp	#'9'+1
	bge	lb6
	ldx	~stringLength
	sta	~string,X
	inc	~stringLength
	cpx	#78
	bge	lb7
lb5	jsl	~GetCharInput
	bra	lb4
lb6	jsl	~PutCharInput
	pha		convert the string into a number
	ph4	#~string
	ph2	~stringLength
	ph2	#1
	_Dec2Int
	bcc	lb8
lb7	error #1	subrange exceeded
lb8	pla		return the result
	plb
	rtl
	end

****************************************************************
*
*  ~ReadLn - read until a line feed is found
*
*  Inputs:
*	1,S - return address
*	4,S - pointer to the file buffer
*
****************************************************************
*
~ReadLn	start
	longa on
	longi on
	using ~FileCom

	sub	(4:filePtr),0

	sub4	filePtr,#~flHeader	point to file, not buffer
lb1	ldy	#~flEOLN	while not eoln do
	lda	[filePtr],Y
	bne	lb2
	ph4	filePtr	  read
	jsl	~GetBuffer
	bra	lb1
lb2	ldy	#~flEOF	if at end of file do not
	lda	[filePtr],Y	  skip the end of line char
	bne	rts
	ph4	filePtr
	jsl	~GetBuffer
rts	return
	end

****************************************************************
*
*  ~ReadLnInput - read until a line feed is found
*
****************************************************************
*
~ReadLnInput start
	longa on
	longi on

lb1	lda	>~EOLNInput	while not eoln do
	bne	lb2
	jsl	~GetCharInput	  read
	bra	lb1
lb2	lda	#0	skip the end of line char
	sta	>~EOLNInput
	rtl
	end

****************************************************************
*
*  ~ReadLong - Read a long integer
*
*  Inputs:
*	1,S - return address
*	4,S - pointer to file buffer
*
*  Outputs:
*	1,S - return address
*	4,S - value read
*
****************************************************************
*
~ReadLong start
	longa on
	longi on
	using ~FileCom
	using ~StringCom
tab	equ	9	TAB key code

filePtr	equ	7	file pointer

	phb
	phk
	plb
	phd
	tsc
	tcd

	sub4	filePtr,#~flHeader	point to file variable, not buffer
lb1	ldy	#~flHeader	skip leading white space
	lda	[filePtr],Y
	and	#$00FF
	cmp	#tab
	beq	lb2
	cmp	#' '
	bne	lb3
lb2	ph4	filePtr
	jsl	~GetBuffer
	bra	lb1
lb3	stz	~stringLength	read the leading sign, if any
	cmp	#'+'
	beq	lb5
	cmp	#'-'
	bne	lb4
	sta	~string
	inc	~stringLength
	bra	lb5
lb4	cmp	#'0'	read the numbers in the string
	blt	lb6
	cmp	#'9'+1
	bge	lb6
	ldx	~stringLength
	sta	~string,X
	inc	~stringLength
	cpx	#78
	bge	lb7
lb5	ldy	#~flEOF
	lda	[filePtr],Y
	bne	lb6
	ph4	filePtr
	jsl	~GetBuffer
	ldy	#~flHeader
	lda	[filePtr],Y
	and	#$00FF
	bra	lb4
lb6	ph4	#0	convert the string into a number
	ph4	#~string
	ph2	~stringLength
	ph2	#1
	_Dec2Long
	pl4	filePtr	save the result
	bcc	lb8
lb7	error #1	subrange exceeded
lb8	pld
	plb
	rtl
	end

****************************************************************
*
*  ~ReadLongInput - Read a long integer from standard in
*
*  Outputs:
*	4,S - result
*
****************************************************************
*
~ReadLongInput start
	longa on
	longi on
	using ~StringCom
tab	equ	9	TAB key code

	phb		save B
	lda	3,S	create return result location
	pha
	lda	3,S
	pha
	phk		set local data bank
	plb

lb1	jsl	~GetCharInput	skip leading white space
	cmp	#tab
	beq	lb1
	cmp	#' '
	beq	lb1
	stz	~stringLength	read the leading sign, if any
	cmp	#'+'
	beq	lb5
	cmp	#'-'
	bne	lb4
	sta	~string
	inc	~stringLength
	bra	lb5
lb4	cmp	#'0'	read the numbers in the string
	blt	lb6
	cmp	#'9'+1
	bge	lb6
	ldx	~stringLength
	sta	~string,X
	inc	~stringLength
	cpx	#78
	bge	lb7
lb5	jsl	~GetCharInput
	bra	lb4
lb6	jsl	~PutCharInput
	ph4	#0	convert the string into a number
	ph4	#~string
	ph2	~stringLength
	ph2	#1
	_Dec2Long
	pla		save the result
	sta	7,S
	pla
	sta	7,S
	bcc	lb8
lb7	error #1	subrange exceeded
lb8	plb
	rtl
	end

****************************************************************
*
*  ~ReadString - Reads a string
*
*  Inputs:
*	1,S - return address
*	4,S - pointer to file buffer
*	8,S - length of string
*	10,S - address of string
*
****************************************************************
*
~ReadString start
	longa on
	longi on
	using ~FileCom
index	equ	0	temporary index
tLen	equ	2	max length of string

	sub	(4:filePtr,2:len,4:ptr),4

	ph4	ptr	convert string to standard form
	ph2	len
	jsr	~StringToMaxStandard
	pl2	tLen
	pl4	ptr

	sub4	filePtr,#~flHeader	point to file variable, not buffer
	stz	index	initialize index

rs1	ldy	#~flEOLN	while not at end of line do
	lda	[filePtr],Y
	bne	rs2
	ldy	#~flHeader	store the character in the string
	short M
	lda	[filePtr],Y
	ldy	index
	sta	[ptr],Y
	long	M
	inc	index	update index
	ph4	filePtr	get a character
	jsl	~GetBuffer
	dec	tLen	see if at end of string
	bne	rs1

rs2	lda	len	if string has a length byte then
	bpl	rs2a
	dec4	ptr	  set the length
	short M
	lda	index
	sta	[ptr]
	long	M
	bra	rs3	else
rs2a	ldy	index	  set end of string marker
	short M
	lda	#0
	sta	[ptr],Y
	long	M

rs3	return
	end

****************************************************************
*
*  ~ReadStringInput - Read a string from standard in
*
*  Inputs:
*	1,S - return address
*	4,S - length of string
*	6,S - address of string
*
****************************************************************
*
~ReadStringInput start
	longa on
	longi on
index	equ	0	temp index
tLen	equ	2	max length of string

	sub	(2:len,4:ptr),4

	phb
	phk
	plb

	ph4	ptr	convert string to standard form
	ph2	len
	jsr	~StringToMaxStandard
	pl2	tLen
	pl4	ptr

	stz	index

	ldx	~EOLNInput	if eoln then goto rs2
	bne	rs2

rs1	anop		repeat
	jsl	~GetCharInput	  read character from standard in
	ldx	~EOLNInput	  if eoln then goto rs2
	bne	rs2
	ldy	index
	short M	  store the character in string
	sta	[ptr],Y
	long	M
	inc	index	  update string index
	dec	tLen	  are we at end of string
	bne	rs1
!			forever

rs2	lda	len	if string has a length byte then
	bpl	rs2a
	dec4	ptr	  set the length
	short M
	lda	index
	sta	[ptr]
	long	M
	bra	rs3	else
rs2a	ldy	index	  set end of string marker
	cpy	len
	bge	rs3
	short M
	lda	#0
	sta	[ptr],Y
	long	M

rs3	plb
	return
	end

****************************************************************
*
*  ~Redirect - redirect input or output
*
*  Inputs:
*	strptr - pointer to the name of the file or device
*	strlen - max length of string
*	ionum - # of device to redirect:
*		0 - standard in
*		1 - standard out
*		2 - error out
*
****************************************************************
*
~Redirect start
	longa on
	longi on
	using ~StringCom

	sub	(2:strlen,4:strptr,2:ionum),0
	phb
	phk
	plb

	lda	strptr	if strptr = nil then
	ora	strptr+2
	bne	lb1
	lla	filename,console	  filename := @'.console'
	bra	lb4	else begin
lb1	ldy	#0	  i := 0;
lb2	short M	  while (i < strlen) and
	lda	[strptr],Y	    (strptr^[i] <> chr(0)) and
	beq	lb3	    (strptr^[i] <> ' ') do begin
	cmp	#' '
	beq	lb3
	sta	~string+1,Y	    string[i+1] := strptr[i];
	iny		    i := i+1;
	cpy	strlen
	ble	lb2	    end;
	dey
lb3	tya		  string[0] := i;
	sta	~string
	long	M
	lla	filename,~string	  filename := @string;
lb4	anop		  end;
	lda	ionum	device := ionum;
	sta	device
	Redirect rdDCB	Redirect(rdDCB);
	plb
	return

console	dw	'.CONSOLE'

rdDCB	anop		redirect DCB
device	ds	2
	dc	i'0'
filename ds	4
	end

****************************************************************
*
*  ~SaveSet - Move a set from the stack to a memory location
*
*  Inputs:
*	set - bytes of the set to save
*	setLen - length of the set to save
*	dest - destination address
*	destLength - length of the destination area
*
****************************************************************
*
~SaveSet start
	longa on
	longi on
set	equ	15
setLen	equ	13
dest	equ	9
destLength equ 7

	phb		init B
	phk
	plb
	phd		set up direct page area
	tsc
	tcd
	lda	setLen	if stack set is too long then
	cmp	destLength
	ble	lb4
	tax		  verify that extra bytes are zero
	short M
lb2	lda	set-1,X
	bne	lb3
	dex
	cpx	destLength
	bne	lb2
	bra	lb6
lb3	long	M
	error #7	  (set overflow)
	bra	lb6	endif
lb4	beq	lb6	else if stack set is too short then
	ldy	destLength	  zero extra bytes in destination
	short M
	lda	#0
lb5	dey
	sta	[dest],Y
	cpy	setLen
	bne	lb5
lb6	anop		endif
	short M	move the set bytes from the stack
	ldx	destLength
	cpx	setLen
	blt	lb6a
	ldx	setLen
lb6a	dex
lb7	lda	set,X
	txy
	sta	[dest],Y
	dex
	bpl	lb7
	long	M
	lda	setLen	fix the return address
	pld
	plx
	ply
	pha
	tsc
	clc
	adc	#10
	adc	1,S
	tcs
	phy		return
	phx
	plb
	rtl
	end

****************************************************************
*
*  ~Seek - Seek a position in a file
*
*  Inputs:
*	1,S - return address
*	4,S - record number to move to
*	6,S - pointer to file buffer
*
****************************************************************
*
~Seek	start
	longa on
	longi on
	using ~FileCom

	sub	(4:recNum,4:filePtr),0
	phb
	phk
	plb

	sub4	filePtr,#~flHeader	point to file variable, not buffer
	ldy	#~flEOF	EOF := false
	lda	#0
	sta	[filePtr],Y
	ldy	#~flEOLN	EOLN := false
	sta	[filePtr],Y
	ldy	#~flRef	set reference number
	lda	[filePtr],Y
	sta	mkRef
	ldy	#~flKind	if file is binary then
	lda	[filePtr],Y
	and	#4
	bne	lb1
	move4 recNum,mkPos	  pos := buffer length * (recnum-1)
	ldy	#2
	lda	[filePtr]
	sta	num
	lda	[filePtr],Y
	sta	num+2
	mul4	mkPos,num
	Set_Mark mkDCB	  set mark
	bra	lb3	else
lb1	stz	mkPos	  set mark to start of file
	stz	mkPos+2
	Set_Mark mkDCB
	ph4	filePtr	  initialize the file buffer
	jsl	~GetBuffer
	lda	recNum	  quit now if no records need skipping
	ora	recNum+2
	beq	lb3
	bra	lb2a
lb2	ph4	filePtr	  read recnum lines
	jsl	~GetBuffer
lb2a	ldy	#~flEOLN
	lda	[filePtr],Y
	beq	lb2
	ph4	filePtr	  skip the eoln
	jsl	~GetBuffer
	lda	recNum	  loop
	bne	lb2b
	dec	recNum+2
lb2b	dec	recNum
	lda	recNum
	ora	recNum+2
	bne	lb2a
lb3	anop		endif
	plb
	return

num	ds	4	work number

mkDCB	anop		SET_MARK DCB
mkRef	ds	2
mkPos	ds	4
	end

****************************************************************
*
*  ~SetCom - common area for dealing with sets
*
****************************************************************
*
~SetCom	privdata
maxSet	equ	256	max length of a set

leftSet	ds	maxSet	left set operand
rightSet ds	maxSet	right set operand
returnSet ds	4	temp buffer for ~LoadSet return addr
returnSet2 ds	4	temp buff for dif, uni, int return adr
setSize	ds	2	size of the set to work on
	end

****************************************************************
*
*  ~SetDifference - find the differences between two sets
*
*  Inputs:
*	two sets on stack
*
****************************************************************
*
~SetDifference start
	longa on
	longi on
	using ~SetCom

	phb		set data bank
	phk
	plb
	pl4	returnSet2	save return address
	clc		compute the set size
	tsc
	adc	1,s
	tax
	lda	>3,X
	cmp	1,S
	bge	lb1
	lda	1,S
lb1	sta	setSize
	ph4	#rightSet	fetch the sets
	ph2	setSize
	jsl	~SaveSet
	ph4	#leftSet
	ph2	setSize
	jsl	~SaveSet
	lda	setSize	compute difference
	inc	A
	lsr	A
	dec	A
	asl	A
	tax
lb4	lda	leftSet,X
	and	rightSet,X
	eor	leftSet,X
	sta	leftSet,X
	dex
	dex
	bpl	lb4
	ph4	#leftSet	place set on stack
	ph2	setSize
	jsl	~LoadSet
	ph4	returnSet2	return
	plb
	rtl
	end

****************************************************************
*
*  ~SetEqu - determine if two sets are equal
*
*  Inputs:
*	two sets on stack
*
*  Outputs:
*	A - 1 if equal, else 0
*	Z - 0 if equal, else 1
*
****************************************************************
*
~SetEqu	start
	longa on
	longi on
	using ~SetCom

	phb		set data bank
	phk
	plb
	pl4	returnSet2	save return address
	clc		compute the set size
	tsc
	adc	1,s
	tax
	lda	>3,X
	cmp	1,S
	bge	lb1
	lda	1,S
lb1	sta	setSize
	ph4	#rightSet	fetch the sets
	ph2	setSize
	jsl	~SaveSet
	ph4	#leftSet
	ph2	setSize
	jsl	~SaveSet
	lda	setSize	scan for differences
	inc	A
	lsr	A
	dec	A
	asl	A
	tax
lb4	lda	leftSet,X
	cmp	rightSet,X
	bne	notequal
	dex
	dex
	bpl	lb4
	ldx	#1
	bra	lb5
notequal ldx	#0
lb5	ph4	returnSet2	return
	plb
	txa
	rtl
	end

****************************************************************
*
*  ~SetIn - see if an integer is in a set
*
*  Inputs:
*	set and integer on stack
*
*  Outputs:
*	A - 1 if true, else 0
*	Z - 0 if false, else 1
*
****************************************************************
*
~SetIn	start
	longa on
	longi on
set	equ	8	set to test for inclusion in
setSize	equ	6	size of the set in bytes
return	equ	3	return address

	phd		set up local DP
	tsc
	tcd
	ldx	setSize	load the integer to check
	lda	set,X
	and	#$0007	set Y to bit number
	tay
	lda	set,X	compute disp into set
	lsr	a
	lsr	a
	lsr	a
	cmp	setSize	not a match if integer is too big
	blt	lb1
	clc
	bra	lb3
lb1	tax		load the byte in the set
	lda	set,X
lb2	lsr	a	shift the bit into C flag
	dey
	bpl	lb2
lb3	lda	#0	form the boolean result
	rol	a
	tay		save the result in Y
	ldx	setSize	remove stuff from stack
	lda	return-1
	sta	set-2,X
	lda	return+1
	sta	set,X
	pld
	cpx	#1
	beq	lb4
	clc
	tsc
	adc	4,S
	adc	#4
	tcs
	tya		set result
	rtl

lb4	clc		special exit for sets of length 1
	tsc
	adc	#5
	tcs
	tya
	rtl
	end

****************************************************************
*
*  ~SetInA - see if an integer is in a set whose address is provided
*
*  Inputs:
*	set and integer on stack
*
*  Outputs:
*	A - 1 if true, else 0
*	Z - 0 if false, else 1
*
****************************************************************
*
~SetInA	start
	longa on
	longi on
int	equ	12	integer to check
set	equ	8	pointer to set to test for inclusion in
setSize	equ	6	size of the set in bytes
return	equ	3	return address

	phd		set up local DP
	tsc
	tcd
	lda	int	set X to bit number
	and	#$0007
	tax
	lda	int	compute disp into set
	lsr	a
	lsr	a
	lsr	a
	cmp	setSize	not a match if integer is too big
	blt	lb1
	clc
	bra	lb3
lb1	tay		load the byte in the set
	lda	[set],Y
lb2	lsr	a	shift the bit into C flag
	dex
	bpl	lb2
lb3	lda	#0	form the boolean result
	rol	a
	tay		save the result in Y
	lda	return-1	remove stuff from stack
	sta	int-2
	lda	return+1
	sta	int
	pld
	clc
	tsc
	adc	#8
	tcs
	tya		set result
	rtl
	end

****************************************************************
*
*  ~SetInclusion - determine if set A >= set B (set B is a subset of A)
*
*  Inputs:
*	two sets on stack
*
*  Outputs:
*	A - 1 if true, else 0
*	Z - 0 if true, else 1
*
****************************************************************
*
~SetInclusion start
	longa on
	longi on
	using ~SetCom

	phb		set data bank
	phk
	plb
	pl4	returnSet2	save return address
	clc		compute the set size
	tsc
	adc	1,s
	tax
	lda	>3,X
	cmp	1,S
	bge	lb1
	lda	1,S
lb1	sta	setSize
	ph4	#rightSet	fetch the sets
	ph2	setSize
	jsl	~SaveSet
	ph4	#leftSet
	ph2	setSize
	jsl	~SaveSet
	lda	setSize	scan for differences
	inc	A
	lsr	A
	dec	A
	asl	A
	tax
lb4	lda	leftSet,X
	and	rightSet,X
	eor	rightSet,X
	bne	false
	dex
	dex
	bpl	lb4
	ldx	#1
	bra	lb5
false	ldx	#0
lb5	ph4	returnSet2	return
	plb
	txa
	rtl
	end

****************************************************************
*
*  ~SetIntersection - find the intersection between two sets
*
*  Inputs:
*	two sets on stack
*
****************************************************************
*
~SetIntersection start
	longa on
	longi on
	using ~SetCom

	phb		set data bank
	phk
	plb
	pl4	returnSet2	save return address
	clc		compute the set size
	tsc
	adc	1,s
	tax
	lda	>3,X
	cmp	1,S
	bge	lb1
	lda	1,S
lb1	sta	setSize
	ph4	#rightSet	fetch the sets
	ph2	setSize
	jsl	~SaveSet
	ph4	#leftSet
	ph2	setSize
	jsl	~SaveSet
	lda	setSize	compute intersection
	inc	A
	lsr	A
	dec	A
	asl	A
	tax
lb4	lda	leftSet,X
	and	rightSet,X
	sta	leftSet,X
	dex
	dex
	bpl	lb4
	ph4	#leftSet	place set on stack
	ph2	setSize
	jsl	~LoadSet
	ph4	returnSet2	return
	plb
	rtl
	end

****************************************************************
*
*  ~SetSize - fix the size of a set
*
*  Inputs:
*	4,S - correct set size
*	6,S - current set size
*	8,S - set
*
****************************************************************
*
~SetSize start
	longa on
	longi on
	using ~SetCom

	lda	4,S	if the set is the correct size then
	cmp	6,S
	bne	lb1
	phb		  remove sizes
	plx
	ply
	pla
	pla
	phy
	phx
	plb
	rtl		  quit

lb1	phb		save return addr
	phk
	plb
	pl4	returnSet2
	pl2	setSize	save correct set size
	ph4	#rightSet	pull set from stack
	lda	setSize
	cmp	5,S
	bge	lb2
	lda	5,S
lb2	pha
	jsl	~SaveSet
	ph4	#rightSet	place set on stack
	ph2	setSize
	jsl	~LoadSet
	pla		remove set length
	ph4	returnSet2	return
	plb
	rtl
	end

****************************************************************
*
*  ~SetUnion - find the union of two sets
*
*  Inputs:
*	two sets on stack
*
****************************************************************
*
~SetUnion start
	longa on
	longi on
	using ~SetCom

	phb		set data bank
	phk
	plb
	pl4	returnSet2	save return address
	clc		compute the set size
	tsc
	adc	1,s
	tax
	lda	>3,X
	cmp	1,S
	bge	lb1
	lda	1,S
lb1	sta	setSize
	ph4	#rightSet	fetch the sets
	ph2	setSize
	jsl	~SaveSet
	ph4	#leftSet
	ph2	setSize
	jsl	~SaveSet
	lda	setSize	compute union
	inc	A
	lsr	A
	dec	A
	asl	A
	tax
lb4	lda	leftSet,X
	ora	rightSet,X
	sta	leftSet,X
	dex
	dex
	bpl	lb4
	ph4	#leftSet	place set on stack
	ph2	setSize
	jsl	~LoadSet
	ph4	returnSet2	return
	plb
	rtl
	end

****************************************************************
*
*  ~ShellID - read the shell identifier
*
*  Inputs:
*	1,S - return address
*	4,S - length of string buffer
*	6,S - pointer to string buffer
*
****************************************************************
*
~ShellID start
	longa on
	longi on
ptr	equ	0	work pointer
tLen	equ	4	max string length
tPtr	equ	6	address of first char of string

	sub	(2:slen,4:sptr),10
	phb
	phk
	plb

	ph4	sPtr	convert to standard form
	ph2	sLen
	jsr	~StringToMaxStandard
	pl2	tLen
	pl4	tPtr

	move4 ~commandLine,ptr	move the addr to a DP work pointer
	ldy	#0	Y = length of string
	lda	ptr	quit if there is no string
	ora	ptr+2
	beq	lb4
	short M
lb3	lda	[ptr],Y	move the string
	sta	[tptr],Y
	iny		  Y := Y+1;
	cpy	tLen
	beq	lb4
	cpy	#8
	bne	lb3	  end;
lb4	long	M

	lda	sLen	if the string has a length byte then
	bpl	lb5
	short M	  set the length
	tya
	sta	[sPtr]
	long	M
	bra	lb6
lb5	cpy	tLen	else if not at end of string then
	bge	lb6
	short M	  set the null terminator
	lda	#0
	sta	[sPtr],Y
	long	M
lb6	plb
	return
	end

****************************************************************
*
*  ~ShiftRight - Shift a value right
*
*  Inputs:
*	A - value to shift
*	X - # bits to shift by
*
*  Outputs:
*	A - result
*
****************************************************************
*
~ShiftRight start
	longa on
	longi on

	txy		if # bits is 0, quit
	beq	rtl
	bpl	lb2	if # bits is < 0 then
lb1	asl	A	  shift left
	inx
	bne	lb1
	bra	rtl	else
lb2	lsr	A	  shift right
	dex
	bne	lb2
rtl	rtl
	end

****************************************************************
*
*  ~SHR4 - Shift a long value right
*
*  Inputs:
*	num1 - value to shift
*	num2 - # bits to shift by
*
*  Outputs:
*	stack - result
*
****************************************************************
*
~SHR4	start
	longa on
	longi on
num1	equ	8	number to shift
num2	equ	4	# bits to shift by

	tsc		set up DP
	phd
	tcd
	lda	num2+2	if num2 < 0 then
	bpl	lb2
	cmp	#$FFFF	  shift left
	bne	zero
	ldx	num2
	cpx	#-34
	blt	zero
lb1	asl	num1
	rol	num1+2
	inx
	bne	lb1
	bra	lb4
zero	stz	num1	  (result is zero)
	stz	num1+2
	bra	lb4
lb2	bne	zero	else shift right
	ldx	num2
	beq	lb4
	cpx	#33
	bge	zero
lb3	lsr	num1+2
	ror	num1
	dex
	bne	lb3

lb4	lda	0	fix stack and return
	sta	num2
	lda	2
	sta	num2+2
	pld
	pla
	pla
	rtl
	end

****************************************************************
*
*  ~StringCom - common area for dealing with strings
*
****************************************************************
*
~StringCom privdata

! Note: ~StringSize assumes l:~string is at least 255

~string	ds	256	string work buffer
~stringLength ds 2	length of current string
	end

****************************************************************
*
*  StringToMaxStandard - Convert a string to max standard form
*
*  "Max Standard form" means the pointer points to the first char
*  of the string, and the length is the max possibe length.  See
*  also ~StringToStandard.
*
*  Inputs:
*	addr - address of string
*	len - length of string
*
*  Outputs:
*	addr - ptr to first char
*	len - current length of string
*
****************************************************************
*
~StringToMaxStandard private
addr	equ	7	string address
len	equ	5	string length

	phd		set up local DP
	tsc
	tcd
	lda	len	if length < 0 then
	bpl	lb5
	inc	a	  if length = -1 then
	bne	lb1
	lda	#1	    len := 1
	sta	len	    {string is a single character}
	bra	lb5	    endif
!			  endif
!			  {string has a length byte}
lb1	sec		  len := -len
	lda	#0
	sbc	len
	sta	len
	inc4	addr	  ++addr {skip length byte}
!			else
!			  {string is already in correct form}

lb5	pld
	rts
	end

****************************************************************
*
*  ~StringCSize - Fix standard string for a standard string parameter
*
*  The result of a built-in string function is being passed as
*  a parameter to a procedure or function that needs a standard
*  Pascal string.  This function converts a standard string to
*  null terminated string.
*
*  Inputs:
*	len - length of the standard string
*	addr - address of the standard string
*
*  Outputs:
*	address of the pstring on stack
*
****************************************************************
*
~StringCSize start
len	equ	9	length of the standard string
addr	equ	11	address of the standard string
saddr	equ	1	result string address

	phb		set up the stack frame
	pha
	pha
	tsc
	phd
	tcd

	lda	len	reserve a result buffer
	ldx	#0
	jsr	~GetSBuffer
	sta	saddr
	stx	saddr+2
	ldy	len	set the null terminator
	short	M
	lda	#0
	sta	[saddr],Y
	long	M
	tya		move the string
	lsr	A
	bcc	lb1
	dey
	lda	[addr],Y
	and	#$00FF
	sta	[saddr],Y
lb1	tya
	bne	lb3
	bra	lb4
lb2	lda	[addr],Y
	sta	[saddr],Y
lb3	dey
	dey
	bne	lb2
	lda	[addr]
	sta	[saddr]
lb4	anop

	pld		set the string address
	pla
	sta	9,S
	pla
	sta	9,S
	lda	3,S
	sta	5,S
	pla
	sta	1,S
	plb
	rtl
	end

****************************************************************
*
*  ~StringPSize - Fix standard string for a pstring parameter
*
*  The result of a built-in string function is being passed as
*  a parameter to a procedure or function that needs a pstring.
*  This function converts a standard string to a pstring.
*
*  Inputs:
*	len - length of the standard string
*	addr - address of the standard string
*
*  Outputs:
*	address of the pstring on stack
*
****************************************************************
*
~StringPSize start
	using	~StringCom
len	equ	4	length of the standard string
addr	equ	6	address of the standard string

	tsc		set up the stack frame
	phb
	phd
	tcd
	phk
	plb

	lda	len	find the length, resticting it to 255
	cmp	#255
	blt	lb1
	lda	#255
lb1	sta	~string	set the length
	tay		copy the string characters
	beq	lb3
	dey
	short	M
lb2	lda	[addr],Y
	sta	~string+1,Y
	dey
	bpl	lb2
	long	M

lb3	lda	#~string	set the string address
	sta	addr
	lda	#^~string
	sta	addr+2
	lda	len-2	return
	sta	len
	pld
	pla
	sta	1,S
	plb
	rtl
	end

****************************************************************
*
*  ~UnPack - UnPack an array
*
*  Inputs:
*	pkAddr - address of packed array
*	pkSize - size of elements in packed array
*	pkEls - # elements in packed array
*	upAddr - addess of unpacked array
*	upSize - size of elements in unpacked array
*	upEls - # elements in unpacked array
*	start - starting index for move
*
****************************************************************
*
~UnPack	start

	sub	(2:start,2:upEls,2:upSize,4:upAddr,2:pkEls,2:pkSize,4:pkAddr),0

	sec		make sure there are enough elements
	lda	upEls
	sbc	start
	cmp	pkEls
	bge	lb1
	error #1	subrange exceeded
	bra	lb4

lb1	ldx	upSize	set start of unpacked array
	lda	start
	jsl	~mul2
	clc
	adc	upAddr
	sta	upAddr
	bcc	lb2
	inc	upAddr+2
	lda	upSize	if elements are of the same size then
	cmp	pkSize
	bne	lb2
	ph4	upAddr	  use ~move to move elements
	ph4	pkAddr
	lda	pkEls
	ldx	pkSize
	jsl	~mul2
	pha
	jsl	~move
	bra	lb4	else
lb2	ldx	pkEls	  while pkEls > 0 do begin
	beq	lb4
lb3	lda	[pkAddr]	    upAddr^ := pkAddr^;
	and	#$00FF
	sta	[upAddr]
	add4	upAddr,#2	    upAddr := upAddr+2;
	inc4	pkAddr	    pkAddr := pkAddr+1;
	dex		    pkEls := pkEls-1;
	bne	lb3	    end;
lb4	return
	end

****************************************************************
*
*  ~UnPack2 - UnPack an array
*
*  Inputs:
*	pkAddr - address of packed array
*	pkSize - size of elements in packed array
*	pkEls - # elements in packed array
*	upAddr - addess of unpacked array
*	upSize - size of elements in unpacked array
*	upEls - # elements in unpacked array
*	start - starting index for move
*
****************************************************************
*
~UnPack2	start

	sub	(4:start,4:upEls,2:upSize,4:upAddr,4:pkEls,2:pkSize,4:pkAddr),0

	sec		make sure there are enough elements
	lda	upEls
	sbc	start
	tax
	lda	upEls+2
	sbc	start+2
	cmp	pkEls+2
	bne	lb0
	cpx	pkEls
lb0	bge	lb1
	error #1	subrange exceeded
	bra	lb4

lb1	ph2	#0	set start of unpacked array
	ph2	upSize
	ph4	start
	jsl	~Mul4
	clc
	pla
	adc	upAddr
	sta	upAddr
	pla
	adc	upAddr+2
	sta	upAddr+2
	lda	upSize	if elements are of the same size then
	cmp	pkSize
	bne	lb2
	ph4	upAddr	  use ~move to move elements
	ph4	pkAddr
	ph4	pkEls
	ph2	#0
	ph2	pkSize
	jsl	~Mul2
	jsl	~LongMove
	bra	lb4	else
lb2	lda	pkEls	  while pkEls > 0 do begin
	ora	pkEls+2
	beq	lb4
	lda	[pkAddr]	    upAddr^ := pkAddr^;
	and	#$00FF
	sta	[upAddr]
	add4	upAddr,#2	    upAddr := upAddr+2;
	inc4	pkAddr	    pkAddr := pkAddr+1;
	dec4	pkEls	    pkEls := pkEls-1;
	bra	lb2	    end;
lb4	return
	end

****************************************************************
*
*  ~WriteChar - Write character
*
*  Inputs:
*	1,S - return address
*	4,S - address of output routine
*	10,S - field width
*	12,S - character
*
****************************************************************
*
~WriteChar start
	longa on
	longi on

	sub	(4:outPut,2:fw,2:char),0

	ldx	fw	if (fw-1) > 0 then
	bmi	error	  flag error if fw <= 0
	bne	lb0
error	error #1
	bra	lb2
lb0	dex
	beq	lb2	  for X = fw-1 downto 0 do
lb1	lda	#' '	    print(' ')
	jsl	~_COut
	dbne	X,lb1	  next
lb2	anop		endif
	lda	char	print the character
	jsl	~_COut
	return
	end

****************************************************************
*
*  ~WriteInteger - Write integer
*
*  Inputs:
*	1,S - return address
*	4,S - address of output routine
*	10,S - field width
*	12,S - integer
*
****************************************************************
*
~WriteInteger start
	longa on
	longi on
cc	equ	0	character counter
string	equ	7	string build area

	sub	(4:outPtr,2:fw,2:int),14
	phb		set data bank
	phk
	plb
	move4 outPtr,3	move outPtr to its proper spot

	stz	cc	cc = 0
	lda	int	if INT < 0 then
	bpl	lb1
	eor	#$FFFF	  INT = 0-INT
	inc	A
	sta	int
	lda	#'-'	  string[cc] = '-'
	sta	string
	inc	cc	  ++cc
lb1	anop		endif
	ldy	#0	Y = 0
lb2	lda	den,Y	while (den[Y] > INT)
	cmp	int
	ble	lb3
	cpy	#10	  and (Y < 10) do
	bge	lb3
	iny		  Y += 2
	iny
	bra	lb2	endwhile
lb3	cpy	#10	if Y == 10 then
	bne	lb4
	ldx	cc	  string[cc] = '0'
	lda	#'0'
	sta	string,X
	inc	cc	  ++cc
	bra	lb7	else
lb4	cpy	#10	  while Y < 10 do
	bge	lb7
	ldx	#'0'	    X = '0'
	lda	int	    while INT >= 0 do
lb5	bmi	lb6
	inx		      ++X
	sec		      INT = INT-den[Y]
	sbc	den,Y
	bra	lb5	    endwhile
lb6	dex		    --X
	clc		    INT = INT+den[Y]
	adc	den,Y
	sta	int
	txa		    string[cc] = X
	ldx	cc
	sta	string,X
	inc	cc	    ++cc
	iny		    Y += 2
	iny
	bra	lb4	  endwhile
lb7	anop		endif
	lda	fw	if FW > cc then
	bmi	error	  flag error if fw <= 0
	bne	lb7a
error	error #1
	bra	lb9
lb7a	cmp	cc
	ble	lb9
	sec		  for X = FW-cc downto 0 do
	sbc	cc
	tax
lb8	lda	#' '	    print(' ')
	jsl	~_COut
	dbne	X,lb8	  next
lb9	anop		endif
	ldx	#0	for X = 0 to cc do
lb10	lda	string,X	  print(string[X])
	jsl	~_COut
	inx		next
	cpx	cc
	blt	lb10

	plb		restore data bank
	return

den	dc	i'10000,1000,100,10,1'
	end

****************************************************************
*
*  ~WriteLine - Write line feed
*
*  Inputs:
*	1,S - return address
*	4,S - address of output routine
*
****************************************************************
*
~WriteLine start
	longa on
	longi on
return	equ	13	RETURN key code

	sub	(4:outPtr),0
	lda	#return	print
	jsl	~_COut
	return
	end

****************************************************************
*
*  ~WriteLineSO - Write line feed to standard out
*
*  Inputs:
*	1,S - return address
*
****************************************************************
*
~WriteLineSO start
	longa on
	longi on

	ph2	#13
	jsl	SysCharOut
	rtl
	end

****************************************************************
*
*  ~WriteLineEO - Write line feed to error out
*
*  Inputs:
*	1,S - return address
*
****************************************************************
*
~WriteLineEO start
	longa on
	longi on

	ph2	#13
	jsl	SysCharErrout
	rtl              
	end

****************************************************************
*
*  ~WriteLong - Write a long integer
*
*  Inputs:
*	1,S - return address
*	4,S - address of output routine
*	10,S - field width
*	12,S - long integer
*
****************************************************************
*
~WriteLong start
	longa on
	longi on
cc	equ	0	character counter
string	equ	7	string build area

	sub	(4:outPtr,2:fw,4:lngint),22
	phb		set data bank
	phk
	plb
	move4 outPtr,3	move outPtr to its proper spot

	stz	cc	cc = 0
	lda	lngint+2	if LNGINT < 0 then
	bpl	lb1
	sub4	#0,lngint,lngint	  LNGINT = 0-LNGINT
	lda	#'-'	  string[cc] = '-'
	sta	string
	inc	cc	  ++cc
lb1	anop		endif
	ldy	#0	Y = 0
lb2	lda	den+2,Y	while (den[Y] > LNGINT)
	cmp	lngint+2
	bne	lb2a
	lda	den,Y
	cmp	lngint
lb2a	ble	lb3
	cpy	#40	  and (Y < 40) do
	bge	lb3
	iny		  Y += 4
	iny
	iny
	iny
	bra	lb2	endwhile

lb3	cpy	#40	if Y == 40 then
	bne	lb4
	ldx	cc	  string[cc] = '0'
	lda	#'0'
	sta	string,X
	inc	cc	  ++cc
	bra	lb7	else
lb4	cpy	#40	  while Y < 10 do
	bge	lb7
	ldx	#'0'	    X = '0'
	lda	lngint+2	    while LNGINT >= 0 do
lb5	bmi	lb6
	inx		      ++X
	sec		      LNGINT = LNGINT-den[Y]
	lda	lngint
	sbc	den,Y
	sta	lngint
	lda	lngint+2
	sbc	den+2,Y
	sta	lngint+2
	bra	lb5	    endwhile
lb6	dex		    --X
	clc		    LNGINT = LNGINT+den[Y]
	lda	lngint
	adc	den,Y
	sta	lngint
	lda	lngint+2
	adc	den+2,Y
	sta	lngint+2
	txa		    string[cc] = X
	ldx	cc
	sta	string,X
	inc	cc	    ++cc
	iny		    Y += 2
	iny
	iny
	iny
	bra	lb4	  endwhile
lb7	anop		endif
	lda	fw	if FW > cc then
	bmi	error	  flag error if fw <= 0
	bne	lb7a
error	error #1
	bra	lb9
lb7a	cmp	cc
	ble	lb9
	sec		  for X = FW-cc downto 0 do
	sbc	cc
	tax
lb8	lda	#' '	    print(' ')
	jsl	~_COut
	dbne	X,lb8	  next
lb9	anop		endif
	ldx	#0	for X = 0 to cc do
lb10	lda	string,X	  print(string[X])
	jsl	~_COut
	inx		next
	cpx	cc
	blt	lb10

	plb		restore data bank
	return

den	dc	i4'1000000000'
	dc	i4'100000000'
	dc	i4'10000000'
	dc	i4'1000000'
	dc	i4'100000'
	dc	i4'10000'
	dc	i4'1000'
	dc	i4'100'
	dc	i4'10'
	dc	i4'1'
	end

****************************************************************
*
*  ~WriteString - Write string
*
*  Inputs:
*	1,S - return address
*	4,S - address of output routine
*	8,S - field width
*	10,S - # chars in string
*	12,S - addr of string
*
****************************************************************
*
~WriteString start
	longa on
	longi on

	sub	(4:outPtr,2:fw,2:numChar,4:saddr),0

	ph4	sAddr	convert to standard form
	ph2	numChar
	jsr	~StringToStandard
	pl2	numChar
	pl4	sAddr

	lda	fw	if fw > numChar then
	beq	error	  flag error if fw <= 0
	bpl	lb0
	cmp	#$8000
	beq	lb2a
error	error #1
	bra	lb2a
lb0	cmp	numChar
	blt	lb2
	beq	lb2a
	sec		  for X = fw-numChar downto 0 do
	sbc	numChar
	tax
lb1	lda	#' '	    print(' ')
	jsl	~_COut
	dbne	X,lb1	  next
	bra	lb2a	else if fw < numChar then
lb2	sta	numChar	  numChar = fw
lb2a	anop		endif
	ldy	#0	for Y = 0 to numChar-1 do
lb3	lda	[saddr],Y	  print(saddr[Y])
	jsl	~_COut
	iny		next
	cpy	numChar
	blt	lb3
	return
	end

****************************************************************
*
*  ~WritelnStringEO - write a string and EOL to error out
*
*  Inputs:
*	sptr - string to write
*
****************************************************************
*
~WritelnStringEO start

	lda	6,S
	pha
	lda	6,S
	pha
	jsl	~WriteStringEO
	jsl	~WriteLineEO
	phb
	pla
	sta	3,S
	pla
	sta	3,S
	plb
	rtl
	end

****************************************************************
*
*  ~WriteStringEO - write a string to error out
*
*  Inputs:
*	sptr - string to write
*
****************************************************************
*
~WriteStringEO start
length	equ	0

	sub	(4:sptr),2

	lda	[sptr]
	and	#$00FF
	beq	lb2
	sta	length
lb1	inc4	sptr
	lda	[sptr]
	and	#$00FF
	pha
	jsl	SysCharErrout
	dec	length
	bne	lb1
lb2	anop

	return
	end

****************************************************************
*
*  ~WritelnStringSO - write a string and EOL to standard out
*
*  Inputs:
*	sptr - string to write
*
****************************************************************
*
~WritelnStringSO start

	lda	6,S
	pha
	lda	6,S
	pha
	jsl	~WriteStringSO
	jsl	~WriteLineSO
	phb
	pla
	sta	3,S
	pla
	sta	3,S
	plb
	rtl
	end

****************************************************************
*
*  ~WriteStringSO - write a string to standard out
*
*  Inputs:
*	sptr - string to write
*
****************************************************************
*
~WriteStringSO start
length	equ	0

	sub	(4:sptr),2

	lda	[sptr]
	and	#$00FF
	beq	lb2
	sta	length
lb1	inc4	sptr
	lda	[sptr]
	and	#$00FF
	pha
	jsl	SysCharOut
	dec	length
	bne	lb1
lb2	anop

	return
	end
