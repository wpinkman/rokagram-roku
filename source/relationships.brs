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

Function CreateUserRelationshipsPosterScreen(user) As Object
	this = {
	
		screen: CreateObject("roPosterScreen"),
		
		user: user,
		
		shouldClose: false,
		
		ProcessEvents: UserSpringboardProcessEvents,
		Show: function() : m.screen.Show() : return invalid : end function,
		
		Run: function() : m.Show() : m.ProcessEvents() : return invalid : end function,
		
		Close: function() :  m.screen.Close() : m.screen = invalid : return m.screen : end function
		
	}

	this.screen.SetMessagePort(GetGlobalPort())

	this.screen.SetListStyle("arced-square")
	SetBreadcrumb(this.screen)
	
	return this
	
End Function
