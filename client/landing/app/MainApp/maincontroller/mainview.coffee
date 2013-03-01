class MainView extends KDView

  viewAppended:->

    @addHeader()
    @createMainPanels()
    @createMainTabView()
    @createSideBar()
    @windowController = @getSingleton("windowController")
    @listenWindowResize()

  addBook:->
    @addSubView new BookView

  setViewState:(state)->
    if state is 'background'
      @contentPanel.setClass 'no-shadow'
      @mainTabView.hideHandleContainer()
    else
      @contentPanel.unsetClass 'no-shadow'
      @mainTabView.showHandleContainer()

    switch state
      when 'application'
        @sidebar.showFinderPanel()
      when 'environment'
        @sidebar.showEnvironmentPanel()
      else
        @sidebar.hideFinderPanel()

  removeLoader:->
    console.trace()
    $loadingScreen = $(".main-loading").eq(0)
    {winWidth,winHeight} = @windowController
    $loadingScreen.css
      marginTop : -winHeight
      opacity   : 0
    @utils.wait 601, =>
      $loadingScreen.remove()
      $('body').removeClass 'loading'

  createMainPanels:->

    @addSubView @panelWrapper = new KDView
      tagName  : "section"


    @panelWrapper.addSubView @sidebarPanel = new KDView
      domId    : "sidebar-panel"

    @panelWrapper.addSubView @contentPanel = new KDView
      domId    : "content-panel"
      cssClass : "transition"

    @registerSingleton "contentPanel", @contentPanel, yes
    @registerSingleton "sidebarPanel", @sidebarPanel, yes

  addHeader:()->

    @addSubView @header = new KDView
      tagName : "header"

    @header.addSubView @logo = new KDCustomHTMLView
      tagName   : "a"
      domId     : "koding-logo"
      # cssClass  : "hidden"
      attributes:
        href    : "#"
      click     : (event)=>
        event.stopPropagation()
        event.preventDefault()
        KD.getSingleton('router').handleRoute null

    @addLoginButtons()

  addLoginButtons:->

    @header.addSubView @buttonHolder = new KDView
      cssClass  : "button-holder hidden"

    mainController = @getSingleton('mainController')

    @buttonHolder.addSubView new KDButtonView
      title     : "Sign In"
      style     : "koding-blue"
      callback  : =>
        mainController.loginScreen.slideDown =>
          mainController.loginScreen.animateToForm "login"

    @buttonHolder.addSubView new KDButtonView
      title     : "Create an Account"
      style     : "koding-orange"
      callback  : =>
        mainController.loginScreen.slideDown =>
          mainController.loginScreen.animateToForm "register"

  createMainTabView:->

    @mainTabHandleHolder = new MainTabHandleHolder
      domId    : "main-tab-handle-holder"
      cssClass : "kdtabhandlecontainer"
      delegate : @

    @mainTabView = new MainTabView
      domId              : "main-tab-view"
      listenToFinder     : yes
      delegate           : @
      slidingPanes       : no
      tabHandleContainer : @mainTabHandleHolder
    ,null

    mainController = @getSingleton('mainController')
    mainController.popupController = new VideoPopupController

    mainController.monitorController = new MonitorController

    @videoButton = new KDButtonView
      cssClass : "video-popup-button"
      icon : yes
      title : "Video"
      callback :=>
        unless @popupList.$().hasClass "hidden"
          @videoButton.unsetClass "active"
          @popupList.hide()
        else
          @videoButton.setClass "active"
          @popupList.show()

    @videoButton.hide()

    @popupList = new VideoPopupList
      cssClass      : "hidden"
      type          : "videos"
      itemClass     : VideoPopupListItem
      delegate      : @
    , {}

    @mainTabView.on "AllPanesClosed", ->
      @getSingleton('router').handleRoute "/Activity"

    @contentPanel.addSubView @mainTabView
    @contentPanel.addSubView @mainTabHandleHolder
    @contentPanel.addSubView @videoButton
    @contentPanel.addSubView @popupList

    getSticky = =>
      @getSingleton('windowController')?.stickyNotification
    getStatus = =>
      KD.remote.api.JSystemStatus.getCurrentSystemStatus (err,systemStatus)=>
        if err
          if err.message is 'none_scheduled'
            getSticky()?.emit 'restartCanceled'
          else
            log 'current system status:',err
        else
          systemStatus.on 'restartCanceled', =>
            getSticky()?.emit 'restartCanceled'
          new GlobalNotification
            targetDate  : systemStatus.scheduledAt
            title       : systemStatus.title
            content     : systemStatus.content
            type        : systemStatus.type

    # sticky = @getSingleton('windowController')?.stickyNotification
    @utils.defer => getStatus()

    KD.remote.api.JSystemStatus.on 'restartScheduled', (systemStatus)=>
      sticky = @getSingleton('windowController')?.stickyNotification

      if systemStatus.status isnt 'active'
        getSticky()?.emit 'restartCanceled'
      else
        systemStatus.on 'restartCanceled', =>
          getSticky()?.emit 'restartCanceled'
        new GlobalNotification
          targetDate : systemStatus.scheduledAt
          title      : systemStatus.title
          content    : systemStatus.content
          type       : systemStatus.type

  createSideBar:->

    @sidebar = new Sidebar domId : "sidebar", delegate : @
    @emit "SidebarCreated", @sidebar
    @sidebarPanel.addSubView @sidebar

  changeHomeLayout:(isLoggedIn)->

  decorateLoginState:(isLoggedIn = no)->

    if isLoggedIn
      if $('.group-landing').length > 0
        if $('.group-loader').length > 0
          $('.group-loader')[0].remove?()
        $('body').addClass "login"
        console.log "LOGGED IN WITH GROUPS"

        LoginLink = new KDCustomHTMLView
          partial: "Login"
          cssClass: "bigLink"
          click: ->
            $('.group-landing').css 'height', 0

        LoginLink.appendToSelector '.group-login-buttons'

        $('.group-landing').css 'height', window.innerHeight - 50

      else
        console.log "LOGGED IN NO GROUPS"
        $('body').addClass "loggedIn"

      @mainTabView.showHandleContainer()
      @contentPanel.setClass "social"  if "Develop" isnt @getSingleton("router")?.getCurrentPath()
      # @logo.show()
      # @buttonHolder.hide()
    else
      if $('.group-landing').length > 0
        unless window._called_once
          a = new KDButtonView
            title: "Click ME!"
            callback: ->
              alert 'Clicked yay!'
          a.appendToSelector '.group-login-buttons'
          window._called_once = yes
      else
        $('body').removeClass "loggedIn"

      @contentPanel.unsetClass "social"
      @mainTabView.hideHandleContainer()
      # @buttonHolder.show()
      # @logo.hide()

    @changeHomeLayout isLoggedIn
    @utils.wait 300, => @notifyResizeListeners()

  _windowDidResize:->

    {winHeight} = @windowController
    @panelWrapper.setHeight winHeight - 51
