' *********************************************************
' *********************************************************
' **
' **  Rokagram Channel
' **
' **  W. Pinkman, February 2014
' **
' **  Copyright (c) 2014 Fugue State, Inc., All Rights Reserved.
' **
' *********************************************************
' *********************************************************

Function CreateRequestHash() As Object
	this = {
		put: RequestHashPut,
		get: RequestHashGet
	}
	return this
End Function

Sub RequestHashPut(identity As Integer, req As Object)
	m[Stri(identity)] = xfer
End Sub

Function RequestHashGet(identity As Integer) As Object
	return m[Stri(identity)]
End Function