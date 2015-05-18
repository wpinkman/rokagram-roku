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

Function CreateUserSpringBoardScreen(user) As Object
	this = {
	
		screen: CreateObject("roSpringboardScreen"),
		xfer: CreateObject("roUrlTransfer"),
		port: CreateObject("roMessagePort"),
		
		user: user,
		content: invalid,
		screenName: "user-springboard",
		
		AddButtons: UserSpringboardAddButtons,
		AddFollowUnfollowButton: UserSpringboardAddFollowUnfollowButton,
		
		HandleRelationShipResponse: UserSpringboardHandleRelationShipResponse,
		
		Initialize: UserSpringboardInitialize,
		
		shouldClose: false,
		
		outgoing_status: invalid,
		
		ProcessEvents: UserSpringboardProcessEvents,
		Show: UserSpringboardShow,
		
		Run: function() : m.Show() : m.ProcessEvents() : return invalid : end function,
		
		Close: function() :  m.screen.Close() :  return m.screen : end function
		
	}

	this.xfer.setPort(this.port)
	this.screen.SetMessagePort(this.port)
	
	this.xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
	this.xfer.InitClientCertificates()

	this.screen.SetCertificatesFile("common:/certs/ca-bundle.crt")
	this.screen.InitClientCertificates()
	
	this.screen.SetPosterStyle("rounded-square-generic")
	this.screen.SetStaticRatingEnabled(false)
	

	this.Initialize()
	
	SetBreadcrumb(this.screen)
	
	AddCloseableScreen(this)
	
	return this
	
End Function

Sub UserSpringboardShow()
	GaScreenView("user-info").PostAsync()
	m.screen.Show()
End Sub

Sub UserSpringboardAddButtons()
	m.btnBack = 0
	m.screen.AddButton(m.btnBack, "Back")	
End Sub	

Sub UserSpringboardInitialize()
	m.screen.ClearButtons()
	m.content = {}
	m.content.title = m.user.username
	if m.user.profile_picture <> invalid
		m.content.SDPosterUrl = m.user.profile_picture
		m.content.HDPosterUrl = m.user.profile_picture
	end if
	m.content.description = "loading bio ..."
	m.screen.SetContent(m.content)
	m.AddButtons()
	
	m.instaRequest = CreateInstaRequest(m.port)
	m.instaRequest.endpoint = "/users/" + m.user.id
	m.userReqTs = CreateObject("roTimeSpan")
	m.instaRequest.StartGetToString()
	
	LogSpringBoardMessage("Browsing  " + m.user.username + "'s profile", m.instaRequest)

	if GetCurrentUser() <> invalid
		m.relationshipStatusRequest = CreateInstaRequest(m.port)
		m.relationshipStatusRequest.endpoint = "/users/" + m.user.id + "/relationship"
		m.relationshipStatusRequest.StartGetToString()
	end if
	
End Sub

Sub UserSpringboardAddFollowUnfollowButton()
	
	if m.outgoing_status = "follows" then
		m.btnUnfollow = 4
		m.screen.AddButton(m.btnUnfollow, "Unfollow " + m.user.username)
	else if m.outgoing_status = "none" then
		m.btnFollow = 5
		m.screen.AddButton(m.btnFollow, "Follow " + m.user.username)
	else
		print "ERROR: outgoing_status:" + m.outgoing_status + " not handled"
	end if
	
End Sub

Function UserSpringboardProcessEvents()
	
	globals = GetGlobals()

	while true 
		if m.shouldClose exit while
		msg = WaitForEvent(0, m.port)
		
        if type(msg)="roUrlEvent" then
        	identity = msg.GetSourceIdentity()
			if msg.GetInt() = 1 then
					json = msg.GetString()
					print chr(10) + tostr(identity) + "::response: code=" + Stri(msg.GetResponseCode()) + chr(10) + json + chr(10)
				if m.instaRequest.identity = identity then
					if msg.GetResponseCode() = 200 then
						
						GaTiming("ig-user-req", m.user.id, m.userReqTs.TotalMilliseconds()).PostAsync()
						parsedResponse = ParseJson(json)
			
						userData = parsedResponse.data
							
						m.content = {}
			
						m.content.title = userData.username
						
						profile_picture = HackStripHttps(userData.profile_picture)
						m.content.SDPosterUrl = profile_picture
						m.content.HDPosterUrl = profile_picture
						m.content.description = userData.bio

						m.content.actors = []
						m.content.actors.Push(userData.full_name)
						m.content.Categories = []

						if userData.website <> invalid then
							m.content.Categories.Push(userData.website)
						end if			
	
						m.screen.SetContent(m.content)
						
						'RegWrite(userData.username, userData.id, SearchHistorySection("users"))
						
						if userData.counts.media > 0 
							m.btnPosts = 1
							btnLabel = Stri(userData.counts.media).Trim() + " Posts"
							if globals.saver
								btnLabel = "Set as Screen Saver"
							end if
							m.screen.AddButton(m.btnPosts, btnLabel)
						end if
	
						if NOT globals.saver
							if userData.counts.followed_by > 0
								m.btnFollowers = 2
								m.screen.AddButton(m.btnFollowers, Stri(userData.counts.followed_by).Trim() + " Followers")
							end if
							
							if userData.counts.follows > 0 
								m.btnFollowing = 3
								m.screen.AddButton(m.btnFollowing, Stri(userData.counts.follows).Trim() + " Following")
							end if
						end if
				
					else if  msg.GetResponseCode() = 400 then
						m.content.description = "This user is private."
						' You need to be following " username " to like or comment
						m.screen.SetContent(m.content)
					
					else
						
						print "ERROR: unextected return code: " + Stri(msg.GetResponseCode()) + ", reason:" + msg.GetFailureReason()
					end if
				else if m.relationshipStatusRequest.identity = identity
				
					if msg.GetResponseCode() = 200
						parsedResponse = ParseJson(json)
						if parsedResponse.meta.code = 200 then
							m.outgoing_status = parsedResponse.data.outgoing_status
							if NOT globals.saver
								m.AddFollowUnfollowButton()
							end if
						end if
					else
						print "Got " + tostr(msg.GetResponseCode()) + " from friendship status request"
					end if
				end if
			else
				
				print "ERROR msg.GetInt() = " + tostr(msg.GetInt())
			end if
		else if type(msg) = "roSpringboardScreenEvent"
		
			if msg.isScreenClosed() then 
				return -1
			else if msg.isRemoteKeyPressed()
				ClearStillListening()
			else if msg.isButtonInfo()
	        	globals.radio.asp.Run()
			else if msg.isButtonPressed() 
				index = msg.GetIndex()
				
				if index = m.btnBack then
					m.screen.Close()
					return 0
				else if index = m.btnPosts
					title = m.user.username + "'s Posts"
					endpoint = "/users/" + m.user.id + "/media/recent"
					if globals.saver
						t = "Search"
		    			WriteScreenSaver("type", t)
		    			WriteScreenSaver("description", title)
		    			instareq = CreateInstaRequest()
		    			instareq.endpoint = endpoint
                		instareq.BuildUrl()
		    		    WriteScreenSaver("url", instareq.url)
		    		    
		    		    ShowScreenSaverSetDialog(title)
		    		    LogScreenSaverMessage(t + " : " + title, instareq.url)
		    		    
		    		    m.screen.Close()
							
					else
						instashow = CreateInstaShow(endpoint)
						instashow.title = title
						instashow.Run()
					end if
					
				else if index = m.btnUnfollow
					unfollowRequest = CreateInstaRequest()
					unfollowRequest.endpoint = "/users/" + m.user.id + "/relationship"
					unfollowRequest.AddBodyParam("action", "unfollow")
					fmsg = unfollowRequest.PostWithStatus("Unfollowing ...")
					if fmsg <> invalid
						GaSocial("unfollow", m.user.id).PostAsync()
					end if
					m.HandleRelationShipResponse(fmsg)
					LogSpringBoardMessage("Unfollwing  " + m.user.username)
				else if index = m.btnFollow
					followRequest = CreateInstaRequest()
					followRequest.endpoint = "/users/" + m.user.id + "/relationship"
					followRequest.AddBodyParam("action", "follow")
					fmsg = followRequest.PostWithStatus("Following ...")
					if fmsg <> invalid
						GaSocial("follow", m.user.id).PostAsync()
					end if
					m.HandleRelationShipResponse(fmsg)
					LogSpringBoardMessage("Follwing  " + m.user.username)
				else if index = m.btnFollowing 
					screen = CreateUsersPoster()
					screen.RunRelations(m.user, "follows")
					LogSpringBoardMessage("Seeing who follows " + m.user.username)
				else if index = m.btnFollowers 
					screen = CreateUsersPoster()
					screen.RunRelations(m.user, "followed-by")
					LogSpringBoardMessage("Seeing who " + m.user.username + " follows")
				end if
			end if
		end if
	end while
End Function

Sub UserSpringboardHandleRelationShipResponse(msg)
	json = msg.GetString()
	response = ParseJson(json)
	' {"meta":{"code":200},"data":{"outgoing_status":"follows","target_user_is_private":false}}
	if response.meta.code = 200 then
		if response.data.outgoing_status <> m.outgoing_status then
			m.Initialize()
		end if
		
	end if
				
End Sub