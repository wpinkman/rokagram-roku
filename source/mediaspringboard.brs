' *********************************************************
' *********************************************************
' **
' **  Rokagram Channel
' **
' **  W. Pinkman, February 2015
' **
' **  Copyright (c) 2015 Fugue State, Inc., All Rights Reserved.
' **
' *********************************************************
' *********************************************************

Function CreateMediaSpringboardScreen(mediaItem) As Object
	this = {
	
		screen: CreateObject("roSpringboardScreen"),
		xfer: CreateObject("roUrlTransfer"),
		port: CreateObject("roMessagePort"),
		
		screenName: "media",
		mediaItem: mediaItem,
		content: invalid,
		
		btnBack:0,
		
		shouldClose: false,
		
		AddButtons: MediaSpringboardAddButtons,
		ProcessEvents: MediaSpringboardProcessEvents,
		SetInstaShow: MediaSpringboardSetInstaShow,
		
		Run: MediaSpringboardRun,
		
		Close: function() :  m.screen.Close() :  return m.screen : end function
		
	}

	this.xfer.setPort(this.port)
	this.screen.SetMessagePort(this.port)
	
	this.xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
	this.xfer.InitClientCertificates()

	this.screen.SetPosterStyle("rounded-square-generic")
	this.screen.SetStaticRatingEnabled(false)

	this.AddButtons()

	this.content = {}
	if GetCurrentUser() = invalid then
		this.content.title = this.mediaItem.user.username
	end if
	
	if this.mediaItem.images <> invalid
		this.content.SDPosterUrl = HackStripHttps(this.mediaItem.images.thumbnail.url)
		this.content.HDPosterUrl = HackStripHttps(this.mediaItem.images.low_resolution.url)
	end if
	
	if this.mediaItem.caption <> invalid then
		this.content.description = this.mediaItem.caption.text
	end if
	
	this.content.Categories = []
	'this.content.Categories.Push(Stri(this.mediaItem.likes.count) + " likes")
	if this.mediaItem.filter <> invalid then
		this.content.Categories.Push("Filter " + this.mediaItem.filter)
	end if
	'if this.mediaItem.location <> invalid
	'	if this.mediaItem.location.name <> invalid
	'		this.content.Categories.Push("Location " + this.mediaItem.location.name)
	'	end if
	'end if
	SetBreadcrumb(this.screen)
	
	this.screen.SetContent(this.content)
	
	AddCloseableScreen(this)
		
	return this
	
End Function

Sub MediaSpringboardAddButtons()
	
	globals = GetGlobals()
	
	m.screen.AllowUpdates(false)
	index = 0

	if globals.features.video AND m.mediaItem.type = "video"
		m.btnPlayVideo = index
		m.screen.AddButton(m.btnPlayVideo, "Play video")
		index = index + 1
	end if
	
	m.btnBack = index
	m.screen.AddButton(m.btnBack, "Back")
	index = index + 1
	
	m.btnUser = index
	m.screen.AddButton(m.btnUser, m.mediaItem.user.username)
	index = index + 1
		
	if GetCurrentUser() <> invalid then
		
		likeToggleCaption = "Like"
		if m.mediaItem.user_has_liked then
			likeToggleCaption = "Unlike"
		end if

		m.btnToggleLike = index
		m.screen.AddButton(m.btnToggleLike, likeToggleCaption)
		index = index + 1
		
	end if
	
	if m.mediaItem.tags <> invalid AND m.mediaItem.tags.Count() > 0 then
		m.btnTags = index
		m.screen.AddButton(m.btnTags, "Tags")
		index = index + 1
	end if
	
	if m.mediaItem.users_in_photo <> invalid AND m.mediaItem.users_in_photo.Count() > 0 then
		m.btnUsersInPhoto = index
		m.screen.AddButton(m.btnUsersInPhoto, "Users In Photo")
		index = index + 1
	end if
	
	if m.mediaItem.likes <> invalid AND m.mediaItem.likes.count > 0 then
		m.btnLikers = index
		m.screen.AddButton(m.btnLikers, Stri(m.mediaItem.likes.count).Trim() + " Likes")
		index = index + 1
	end if

	m.screen.AllowUpdates(true)
End Sub

Sub MediaSpringboardSetInstaShow(instashow)
	m.instashow = instashow
	m.screen.AllowNavLeft(false)
	m.screen.AllowNavRight(false)
End Sub

Function MediaSpringboardRun()
	m.screen.Show()
	
	GaScreenView(m.screenName).PostAsync()
	
	instaReqToLog = CreateInstaRequest()
	instaReqToLog.endpoint = "/media/" + m.mediaItem.id
	instaReqToLog.BuildUrl()
	
	LogSpringBoardMessage("Browsing to a photo posted by " + m.mediaItem.user.username, instaReqToLog)
	
	m.ProcessEvents()
	return invalid	
End Function

Function MediaSpringboardProcessEvents()

	globals = GetGlobals()
	
	while true 
		if m.shouldClose exit while
		msg = WaitForEvent(0, m.port)
		
		if type(msg) = "roSpringboardScreenEvent"
			index = msg.GetIndex()
			if msg.isScreenClosed() then 
				return -1
			else if msg.isRemoteKeyPressed() then
				print "MediaSpringboardProcessEvents::isRemoteKeyPressed, index:" + tostr(index)
			else if msg.isButtonInfo()
	        	globals.radio.asp.Run()
			else if msg.isButtonPressed() 
				'print "msg: "; msg.GetMessage(); "idx: "; msg.GetIndex()
			
				
				if msg.GetIndex() = m.btnBack then
					m.screen.Close()
					return 0
				else if m.btnUser <> invalid AND msg.GetIndex() = m.btnUser then
					userSpringboard = CreateUserSpringboardScreen(m.mediaItem.user)
					userSpringboard.Run()
					
				else if m.btnToggleLike <> invalid AND msg.GetIndex() = m.btnToggleLike then
					likeRequest = CreateInstaRequest()
					likeRequest.endpoint = "/media/" + m.mediaItem.id + "/likes"
					lkmsg = invalid
					sa = "like"
					if m.mediaItem.user_has_liked then
						lkmsg = likeRequest.DeleteWithStatus("Removing like..")
						sa = "unlike"
						LogSpringBoardMessage("Removing like from id:" + m.mediaItem.id)
					else
						lkmsg = likeRequest.PostWithStatus("Liking...")
						LogSpringBoardMessage("Liking id:" + m.mediaItem.id)
					end if
					
					GaEvent(type(msg), "btnToggleLike").PostAsync()
					
					print "Returned: " + tostr(lkmsg)
					if lkmsg <> invalid then
					
						GaSocial(sa, m.mediaItem.id).PostAsync()
					
						m.mediaItem.user_has_liked = NOT m.mediaItem.user_has_liked
						m.screen.ClearButtons()
						m.AddButtons()
					end if
				else if m.btnLikers <> invalid AND msg.GetIndex() = m.btnLikers
					screen = CreateUsersPoster()
					screen.RunLikers(m.mediaItem.id)
					LogSpringBoardMessage("Perusing likers of id:" + m.mediaItem.id)
				else if m.btnTags <> invalid AND msg.GetIndex() = m.btnTags
				
					GaEvent(type(msg), "btnTags").PostAsync()
					
					tag = ChooseTag(m.mediaItem.tags)
					if tag <> invalid then
						xfer = CreateObject("roUrlTransfer")
						instashow = CreateInstaShow( "/tags/" + xfer.UrlEncode(tag) + "/media/recent")
						instashow.title = "#" + tag
						instashow.Run()
						
					end if
				else if m.btnUsersInPhoto <> invalid AND msg.GetIndex() = m.btnUsersInPhoto then
					LogSpringBoardMessage("Perusing users in id:" + m.mediaItem.id)
					users = []
					for each item in m.mediaItem.users_in_photo
						users.Push(item.user)
					next
					screen = CreateUsersPoster(users)
					screen.Run()
				else if m.btnPlayVideo <> invalid AND msg.GetIndex() = m.btnPlayVideo
					PlayInstagramVideo(m.mediaItem)
				end if
			endif
		end if
	end while
End Function

