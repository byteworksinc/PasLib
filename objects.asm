	keep	obj/objects
	mcopy	objects.macros
****************************************************************
*
*  Object Libraries
*
*  These libraries are for use with the 65816 ORCA/Pascal
*  native code compiler.
*
*  Copyright 1993
*  Byte Works, Inc.
*  All rights reserved.
*
*  By Mike Westerfield
*  February 1993
*
****************************************************************
*
Dummy	start
	end

****************************************************************
*
*  ~NewOjbect - Allocate and initialize a new object
*
*  Inputs:
*    Inputs are pushed on teh stack as follows:
*	addr - address of the object variable
*	family - (word) family number
*	size - (long) size of the object
*	methods - For each method, two longs are pushed:
*		function address
*		disp in object
*	count - number of method parameters
*
****************************************************************
*
~NewObject start

	tsc		set up two pointer workspaces
	sec
	sbc	#8
	tcs
	phd
	tcd
	lda	12	push the object family
	asl	A
	asl	A
	asl	A   
	tax
	lda	18,X
	pha
	lda	16,X	push the size of the object, twice
	tay
	lda	14,X
	phy
	pha
	phy
	pha
	lda	20,X	save the address of the pointer
	sta	5
	lda	22,X
	sta	7
	jsl	~New	allocate memory (uses one size from stack)
	sta	1	save the pointer
	stx	3
	sta	[5]
	txa
	ldy	#2
	sta	[5],Y

	ora	1	handle an out of memory error
	bne	lb1
	ph2	#5
	jsl	SystemError
	pla
	pla
	pla
	pld
	pla
	pla
	pla
	pla
	phb
	plx
	ply
	pla
	asl	A
	asl	A
	asl	A
	adc	#12
	pha
	tsc
	clc
	adc	1,S
	tcs
	phy
	phx
	plb
	rtl

lb1	pla		set the object size
	sta	[1]
	ldy	#2
	pla
	sta	[1],Y
	ldy	#4	set the object generation
	pla
	sta	[1],Y
	lda	12	for each method do
	beq	lb3
	phb
	phk
	plb
	sta	count
	ldx	#14
	ldy	#2
lb2	clc		  find the save address
	lda	0,X
	adc	1
	sta	5
	lda	2,X
	adc	3
	sta	7
	lda	4,X	  save the method address
	sta	[5]
	lda	6,X
	sta	[5],Y
	txa		  X += 8
	clc
	adc	#8
	tax
	dec	count	loop
	bne	lb2
	plb

lb3	lda	12	fix the stack and return
	asl	A
	asl	A
	asl	A
	clc
	adc	#20
	tax
	lda	10
	sta	2,X
	lda	9
	sta	1,X
	pld
	tsc
	phx	
	clc
	adc	1,S
	tcs
	rtl

count	ds	2	loop counter
	end

****************************************************************
*
*  function Member (object: tObject; generation: boolean): boolean
*
*  parameters:
*	object - object to check
*	generation - generation of the object type
*
****************************************************************
*
~Member	start
result	equ	1	result of the call

genDisp	equ	4	disp of generation in an object

	sub	(4:object,2:generation),2

	stz	result
	lda	object
	ora	object+2
	beq	lb1
	ldy	#genDisp
	lda	generation
	beq	lb1
	cmp	[object],Y
	bgt	lb1
	inc	result
	
lb1	ret	2:result
	end

****************************************************************
*
*  function Clone: tObject
*
*  Creates a copy of an object
*
****************************************************************
*
tObject~Clone start

	jml	tObject~ShallowClone
	end

****************************************************************
*
*  procedure Free
*
*  Disposes of an object
*
****************************************************************
*
tObject~Free start

	jml	tObject~ShallowFree
	end

****************************************************************
*
*  function ShallowClone: tObject
*
*  Creates a copy of an object
*
****************************************************************
*
tObject~ShallowClone start

object	equ	1	copy of the object

	sub	(4:self),4

	ldy	#2	allocate space for the copy
	lda	[self],Y
	pha
	lda	[self]
	pha
	jsl	~New
	sta	object
	stx	object+2
	ora	object+2	check for out of memory error
	bne	lb1
	ph2 #5	out of memory
	jsl	SystemError
	bra	lb2

lb1	ph4	object	copy the object contents
	ph4	self
	ldy	#2
	lda	[self],Y
	pha
	lda	[self]
	pha
	jsl	~LongMove

lb2	ret	4:object
	end

****************************************************************
*
*  procedure ShallowFree
*
*  Disposes of an object
*
****************************************************************
*
tObject~ShallowFree start

	jml	~Dispose
	end
