' ***************************************************************
' ***************************************************************
' **
' **  Rokagram Channel
' **
' **  W. Pinkman, February 2014
' **
' **  Copyright (c) 2014 Fugue State, Inc., All Rights Reserved.
' **
' ***************************************************************
' ***************************************************************

Function CreateUsersPoster(users=invalid)
	this = {
		
		screen: CreateObject("roPosterScreen"),
		port: CreateObject("roMessagePort")
		
		shouldClose: false,
		users: invalid,
		contrib_mode: false,
		
		ProcessResponse: UsersPosterProcessResponse,
		ProcessParsedResponse: UsersPosterProcessParsedResponse, 
		PopulateContent: UsersPosterPopulateContent,
		ProcessEvents: UsersPosterProcessEvents,
		
		Run: UsersPosterRun,
		RunRelations: UsersPosterRunRelations,
		RunLikers: UsersPosterRunLikers,
		RunSearchResults: UsersPoserRunSearchResults,
		
		Close: function() :  m.screen.Close() : m.screen = invalid : return m.screen : end function
		
	}

	this.screen.SetMessagePort(this.port)
	this.screen.SetListStyle("arced-square")
	
	this.screen.SetCertificatesFile("common:/certs/ca-bundle.crt")
	this.screen.InitClientCertificates()


	if users <> invalid 
		this.users = users
		this.PopulateContent()
	end if
	
	SetBreadcrumb(this.screen)

	AddCloseableScreen(this)

	return this

End Function

Sub UsersPosterRunRelations(baseUser, relationship_endpoint)
	m.screen.Show()
	
	GaScreenView(relationship_endpoint).PostAsync()
	
	req = CreateInstaRequest(m.port)
	req.endpoint = "/users/" + baseUser.id + "/" + relationship_endpoint
	if baseUser.access_token <> invalid AND m.contrib_mode
		req.access_token = baseUser.access_token
	end if
	json = req.GetToString()
	
	m.ProcessResponse(json)
	
	m.ProcessEvents()
End Sub

Sub UsersPoserRunSearchResults(parsedResponse)
	m.screen.Show()
	GaScreenView("search-results").PostAsync()
	m.ProcessParsedResponse(parsedResponse)
	m.ProcessEvents()
End Sub

Sub UsersPosterRunLikers(mediaId)
	m.screen.Show()
	
	GaScreenView("likers").PostAsync()
	
	req = CreateInstaRequest(m.port)
	req.endpoint = "/media/" + mediaId + "/likes"
	json = req.GetToString()
	
	m.ProcessResponse(json)
	
	m.ProcessEvents()
End Sub

Sub UsersPosterPopulateContent()
	contentList = []
	userList = []
	
	awaddell2003 = invalid
	darrenhalbig = invalid
	
	for each user in m.users 
		item = {}
		item.user = user
		profile_picture = HackStripHttps(user.profile_picture)
		item.SDPosterUrl = profile_picture
		item.HDPosterUrl = profile_picture
		item.ShortDescriptionLine1 = user.username
		item.ShortDescriptionLine2 = user.full_name
	
		if m.contrib_mode AND user.username = "awaddell2003"
			awaddell2003 = item
		else if m.contrib_mode AND user.username = "darrenhalbig"
			darrenhalbig = item
		else
			userList.Push(item)
		end if
	next
	
	if awaddell2003 <> invalid
		contentList.Push(awaddell2003)
	end if
	if darrenhalbig <> invalid
		contentList.Push(darrenhalbig)
	end if

	for each item in userList
		contentList.Push(item)
	next
	
	if m.next_url <> invalid
		item = {}
		item.next_url = m.next_url
		item.ShortDescriptionLine1 = "More"
		item.HdPosterUrl = "pkg:/images/arrow-right-hd.png"
		item.SdPosterUrl = "pkg:/images/arrow-right-sd.png"
		contentList.Push(item)
	end if

	print "Added " + Stri(contentList.Count()) + " users to poster"
	
	m.screen.SetContentList(contentList)
	
End Sub

Sub UsersPosterProcessResponse(json)
	relResp = ParseJson(json)
	m.ProcessParsedResponse(relResp)
End Sub

Sub UsersPosterProcessParsedResponse(relResp)
	if relResp <> invalid AND relResp.meta <> invalid AND relResp.meta.code = 200
		if relResp.pagination <> invalid AND relResp.pagination.next_url <> invalid
			m.next_url = relResp.pagination.next_url
		end if
		m.users = relResp.data
		m.PopulateContent()
	else
		print "ERROR: bad response from Instagram"
		m.screen.Close()
	end if
End Sub

Sub UsersPosterRun()
	m.screen.Show()
	m.PopulateContent()
	m.ProcessEvents()
End Sub

Function UsersPosterProcessEvents()
	
	globals = GetGlobals()
	
	while true
	
		if m.shouldClose exit while
			
		msg = WaitForEvent(0, m.port)
		
		if type(msg) = "roPosterScreenEvent" 
			
			msgIndex = msg.getIndex()
			
			if msg.isListItemSelected() then
				
				contentItem = m.screen.GetContentList()[msgIndex]
    	
    			if contentItem.user <> invalid
					user = contentItem.user
					userSpringboard = CreateUserSpringBoardScreen(user)
					userSpringboard.Run()
				else if contentItem.next_url <> invalid
					 ir = CreateInstaRequest()
					 ir.url = contentItem.next_url
					 m.screen.SetContentList([])
					 m.screen.Show()
					 m.screen.ShowMessage("Loading...")
					 json = ir.GetToString()
					 m.ProcessResponse(json)
					 m.screen.ClearMessage()
					 m.screen.SetFocusedListItem(0)
					 m.screen.Show()
				end if 
			else if msg.isListItemFocused()
				'print "ListItemFocused:" + tostr(msgIndex) 
	        else if msg.IsListItemInfo()
	        	globals.radio.asp.Run()
			else if msg.isScreenClosed() 
				exit while
			end if
			
		end if
	end while
	return 0
End Function