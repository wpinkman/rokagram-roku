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

Function CreateUserPosterScreen(user) As Object
	this = {
	
		screen: CreateObject("roPosterScreen"),
		http: CreateHttpRequest(),
		port: CreateObject("roMessagePort"),
		
		user: user,
		
		ProcessEvents: SlideShowProcessEvents,
		Show: function() : m.screen.Show() : return invalid : end function
		Run: UserPosterScreenRun,
		
		Close: function() : m.http.Close() : m.screen.Close() : m.port = invalid : m.screen = invalid : return m.screen : end function
		
	}

	this.screen.SetMessagePort(this.port)
	this.http.SetMessagePort(this.port)
	
	this.screen.SetCertificatesFile("common:/certs/ca-bundle.crt")
	this.screen.AddHeader("X-Roku-Reserved-Dev-Id", "")
	this.screen.InitClientCertificates()
	
	this.http.SetUserid(user.id)
	
	this.screen.SetListStyle("arced-square")
    
	return this
	
End Function

Function UserPosterScreenRun()

	closed = false
	m.http.xfer.SetUrl(GetServer() + "/api/users/" + m.user.id)

	json = m.http.xfer.GetToString()
	print json
	
	response = ParseJson(json)
	
	' alway add one to the end for linking/adding accounts
	regScreenMeta = {}
	regScreenMeta.ShortDescriptionLine1 = "Remove Account"
	
	
	response.contentList.Push(regScreenMeta)
	
	
	m.screen.SetContentList(response.contentList)
	m.screen.SetTitle(response.settings.title)
	if response.settings.listStyle <> invalid then
		m.screen.SetListStyle(response.settings.listStyle)
	end if
	if response.settings.listDisplayMode <> invalid then
		m.screen.SetListDisplayMode(response.settings.listDisplayMode)
	end if
	if response.settings.breadCrumbLocation1 <> invalid or response.settings.breadCrumbLocation2 <> invalid then
		m.screen.SetBreadcrumbText(response.settings.breadCrumbLocation1, response.settings.breadCrumbLocation2)
		m.user.username = response.settings.breadCrumbLocation2
		m.screen.SetBreadcrumbEnabled(true)
	end if
	
	' TEMP HACK
	m.screen.SetFocusedListItem(3)
	
	
	while true
		
		msg = wait(0, m.port)
		
		if type(msg) = "roPosterScreenEvent" then
			 'print "event.GetType()=";msg.GetType(); " Event.GetMessage()= "; msg.GetMessage()
			if msg.isListItemSelected() then
				if msg.GetIndex() <  m.screen.GetContentList().Count() - 1 then
	    			meta = m.screen.GetContentList()[msg.GetIndex()]
		
					if meta.screenType = "SlideShow" then
						meta.userid = m.user.id
						meta.title = meta.shortDescriptionLine1
		    			StartSlideShow(meta)
					else if meta.screenType = "UserSearchScreen" then
						ShowSearchScreen(m.user)
					end if
				else 
					if RunRemoveAccount(m.meta) = 1 then
						m.Close()
						return 0
					end if
				end if
			else if msg.isScreenClosed() then
				m.Close()
				return 0
			end if
		end if
		
	end while
			
	return 1
	
End Function

Function RunRemoveAccount(meta)
	screen = CreateObject("roParagraphScreen")
	screen.SetMessagePort(CreateObject("roMessagePort"))

	screen.AddHeaderText("Remove Account?")
	screen.AddParagraph("Disconnect ")
	screen.AddButton(0, "Cancel")
	screen.AddButton(1, "Remove Account")
	screen.Show()
	
	while true
	    msg = wait(0, screen.GetMessagePort())
	
	    if type(msg) = "roParagraphScreenEvent"
	        if msg.isScreenClosed()
	            print "Screen closed"
	            exit while                
	        else if msg.isButtonPressed()
	            if msg.GetIndex() = 1 then
	            	print "Removing token:" + meta.userToken
	            	RegDeleteUser(meta.userToken)
	            	return 1
	            end if
	            return 0
	        else
	            print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
	            exit while
	        endif
	    endif
	end while
		
	return 0
	
End Function
