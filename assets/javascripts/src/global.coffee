html = document.documentElement
attToCheck = ["pointerEvents", "opacity"]
for att in attToCheck 
  if html.style["pointerEvents"]?
    $(html).addClass(att) 
  else
    $(html).addClass("no-#{att}") 
###
# class ModalBox {{{
###
class Modalbox
  constructor: () ->
    @modal   = $('<div class="modal"><div class="padding"></div></div>')
    @overlay = $('<span class="overlay"></span>') 
    $('body').append(@modal)
    $('body').append(@overlay)
    
    @overlay.bind('click', @close)
    
  open: ()->
    @modal.addClass('visible')
    @overlay.addClass('visible')
    
  close: () =>
    @modal.addClass('fadding')
    @overlay.addClass('fadding')
    t = setTimeout(()=>
      @modal.removeClass('visible fadding')
      @overlay.removeClass('visible fadding')
    , 150)
    
###
#}}} 
###

###
# class Confirmbox {{{
###
class Confirmbox extends Modalbox
  constructor: (template) ->
    super
    @modal.addClass('confirm-box')
    @template = template
  
  initConfirmation: (contentString, callback)->
    confirmMessage = { confirmMessage : contentString}
    confirmBoxContent = $(@template(confirmMessage))
    acceptBtn = confirmBoxContent.find('#accept')
    deniedBtn = confirmBoxContent.find('#denied')
    @modal.find('.padding').html(confirmBoxContent)
    
    acceptBtn.bind('click', ()=>
      callback()
      @close()
    )
    deniedBtn.bind('click', @close)
    
    @open();
###
#}}} 
###

###
# classCustomMap {{{
###
class CustomMap
  constructor: (id)->
    @blankTilePath = 'tiles/00empty.jpg'
    @iconsPath     = 'assets/images/icons/32x32'
    @maxZoom       = 7
    @appState      = "read"
    # HTML element
    @html             = $('html')
    @lngContainer     = $('#long')
    @latContainer     = $('#lat')
    @devModInput      = $('#dev-mod')
    @optionsBox       = $('#options-box')
    @addMarkerLink    = $('#add-marker')
    @removeMarkerLink = $('#remove-marker')
    @markerList       = $('#marker-list')
    @exportBtn        = $('#export')
    @exportWindow     = $('#export-windows')
    @markersOptionsMenu = $('#markers-options')
    @editionsTools    = $('#edition-tools a')

    @defaultLat = 25.760319754713887
    @defaultLng = -35.6396484375
    @defaultCat = "generic"
    
    $.get('assets/javascripts/templates/confirmBox._', (e)=>
      template = _.template(e);
      @confirmBox = new Confirmbox(template)
    )
    @areaSummaryBoxes = []
    
    @editInfowindowTemapl
    
    @canRemoveMarker  = false
    @draggableMarker  = false
    @visibleMarkers   = true
    @canToggleMarkers = true
    @currentOpenedInfoWindow = false
    @gMapOptions   = 
      center: new google.maps.LatLng(@getStartLat(), @getStartLng())
      zoom: 6
      minZoom: 3
      maxZoom: @maxZoom
      streetViewControl: false
      mapTypeControl: false
      mapTypeControlOptions:
        mapTypeIds: ["custom", google.maps.MapTypeId.ROADMAP]

      panControl: false
      zoomControl: true
      zoomControlOptions:
        position: google.maps.ControlPosition.LEFT_CENTER
        zoomControlStyle: google.maps.ZoomControlStyle.SMALL
        
    @customMapType = new google.maps.ImageMapType(
      getTileUrl : (coord, zoom)=>
        normalizedCoord = coord
        if normalizedCoord && (normalizedCoord.x < Math.pow(2, zoom)) && (normalizedCoord.x > -1) && (normalizedCoord.y < Math.pow(2, zoom)) && (normalizedCoord.y > -1)
          path = 'tiles/' + zoom + '_' + normalizedCoord.x + '_' + normalizedCoord.y + '.jpg'
        else 
          return @blankTilePath
      tileSize: new google.maps.Size(256, 256)
      maxZoom: @maxZoom
      name: 'GW2 Map'
    )
    
    @map = new google.maps.Map($(id)[0], @gMapOptions)
    @map.mapTypes.set('custom', @customMapType)
    @map.setMapTypeId('custom')

    @addMenuIcons()
    
    # Events
    google.maps.event.addListener(@map, 'click', (e)=>
      console.log '{"lat" : "'+e.latLng.lat()+'", "lng" : "'+e.latLng.lng()+'", "title" : "", "desc" : ""},'
    )
    
    google.maps.event.addListener(@map, 'zoom_changed', (e)=>
        zoomLevel = @map.getZoom()
        if zoomLevel == 4
          @canToggleMarkers = false
          @hideMarkersOptionsMenu()
          @setAllMarkersVisibility(false)
          @setAreasInformationVisibility(true)
          if @currentOpenedInfoWindow then @currentOpenedInfoWindow.close()
        else if zoomLevel > 4
          @canToggleMarkers = true
          @showMarkersOptionsMenu()
          @setAllMarkersVisibility(true)
          @setAreasInformationVisibility(false)
        else if zoomLevel < 4
          @canToggleMarkers = false
          @hideMarkersOptionsMenu()
          @setAllMarkersVisibility(false)
          @setAreasInformationVisibility(false)
          if @currentOpenedInfoWindow then @currentOpenedInfoWindow.close()
    )
    
    #marker
    @gMarker = {}

    @editInfoWindowTemplate = ""
    $.get('assets/javascripts/templates/customInfoWindow._', (e)=>
      @editInfoWindowTemplate = _.template(e)
      
      @setAllMarkers()  
      @initializeAreaSummaryBoxes()
    
      @markerList.find('span').bind('click', (e)=>
        this_      = $(e.currentTarget)
        markerType = this_.attr('data-type')
        coord       = @map.getCenter()
        markerinfo = 
          "lng" : coord.lng()
          "lat" : coord.lat()
          "title" : "--"
        img        = "#{@iconsPath}/#{markerType}.png"
        @addMarkers(markerinfo, img, markerType)
      )
    
      # UI
      @addMarkerLink.bind('click', @toggleMarkerList)
      @removeMarkerLink.bind('click', @handleMarkerRemovalTool)
      @exportBtn.bind('click', @handleExport)
      @editionsTools.bind('click', @handleEdition)
    
      @exportWindow.find('.close').click(()=>
        @exportWindow.hide()
      )
    )
    
  addMarker:(markerInfo, markersType, markersCat)->
    iconsize = 32;
    iconmid = iconsize / 2;
    image = new google.maps.MarkerImage(@getIconURLByType(markersType, markersCat), null, null,new google.maps.Point(iconmid,iconmid), new google.maps.Size(iconsize, iconsize));
    isMarkerDraggable = if markerInfo.draggable? then markerInfo.draggable else false
    marker = new google.maps.Marker(
      position: new google.maps.LatLng(markerInfo.lat, markerInfo.lng)
      map: @map
      icon: image
      visible: if markersCat is @defaultCat then yes else no
      draggable: isMarkerDraggable
      cursor : if isMarkerDraggable then "move" else "pointer"
      title: "#{markerInfo.title}"
    )

    marker["title"] = "#{markerInfo.title}"
    marker["desc"]  = "#{markerInfo.desc}"
    marker["wikiLink"]  = "#{markerInfo.wikiLink}"
    marker["type"]  = "#{markersType}"

    
    # permalink = '<p class="marker-permalink"><a href="?lat=' + markerInfo.lat+ '&lng=' + markerInfo.lng + '">Permalink</a></p>'
    # infoWindow = new google.maps.InfoWindow(
      # content  : editInfoWindowContent
      # maxWidth : 200
    # )
    
    # test = new CustomInfoWindow(marker, editInfoWindowContent)
    
    # marker["infoWindow"] = infoWindow
    # marker["test"] = test
    
    markerThatMatchUrl = @getMarkerByCoordinates(@getStartLat(), @getStartLng())
    if (markerThatMatchUrl == markerInfo)
        marker.infoWindow.open(@map, marker)
        @currentOpenedInfoWindow = marker.infoWindow
    
    # google.maps.event.addListener(marker, 'dragend', (e)=>
    #   console.log '{"lat" : "'+ e.latLng.lat() +'", "lng" : "'+ e.latLng.lng() +'", "title" : "", "desc" : ""},'
    # )
    google.maps.event.addListener(marker, 'click', (e)=>
      closeCurrentInfoWindow = ()=>
        
      switch @appState
        when "remove"
          @removeMarker(marker.__gm_id, markersType, markersCat)
        when "move"
          if marker.getDraggable()
            marker.setDraggable(false)
            marker.setCursor("pointer")
          else
            marker.setDraggable(true)
            marker.setCursor("move")
        else
          # Handling infoWindow, creating them is their're not
          if marker["infoWindow"]?
            if @currentOpenedInfoWindow is marker["infoWindow"]
              @currentOpenedInfoWindow.close()
              
            else
              if @currentOpenedInfoWindow then @currentOpenedInfoWindow.close()
              marker["infoWindow"].open()
          else  
            templateInfo = 
              id : marker.__gm_id
              title : marker.title
              desc  : marker.desc
              type  : marker.type
              wikiLink  : marker.wikiLink
          
            editInfoWindowContent = @editInfoWindowTemplate(templateInfo)
            marker["infoWindow"] = new CustomInfoWindow(marker, editInfoWindowContent,
              onClose : () =>
                @currentOpenedInfoWindow = null
              onOpen  : (infoWindow) =>
                @currentOpenedInfoWindow = infoWindow
            )
            
            if @currentOpenedInfoWindow then @currentOpenedInfoWindow.close()
            marker["infoWindow"].open()
          # console.log marker.test
          # marker.test.setVisible(true)
          # if @currentOpenedInfoWindow then @currentOpenedInfoWindow.close()
          # marker.infoWindow.open(@map, marker)
          # marker.infoWindow.show()
    )
    
    markerType["markers"].push(marker) for markerType in @gMarker[markersCat]["markerGroup"] when markerType.slug is markersType
  setAllMarkers:()->
    for markersCat, markersObjects of Markers
      if not @gMarker[markersCat]?
        @gMarker[markersCat] = {}
        @gMarker[markersCat]["name"] = markersObjects.name
        @gMarker[markersCat]["markerGroup"] = []
        
      for markerTypeObject, key in markersObjects.markerGroup
        newmarkerTypeObject = {}
        newmarkerTypeObject["name"] = markerTypeObject.name
        newmarkerTypeObject["slug"] = markerTypeObject.slug
        newmarkerTypeObject["markers"] = []
        @gMarker[markersCat]["markerGroup"].push(newmarkerTypeObject)
        
        @addMarker(marker, markerTypeObject.slug, markersCat) for marker in markerTypeObject.markers
    
  getIconURLByType:(type, markersCat)->
    return Resources.Icons[markersCat][icon].url for icon of Resources.Icons[markersCat] when icon is type

  setAllMarkersVisibility:(isVisible)->
    for cat, markersObjects of Markers
      @setMarkersVisibilityByType(isVisible, markerTypeObject.slug, cat) for markerTypeObject in markersObjects.markerGroup when not $("[data-type='#{markerTypeObject.slug}']").hasClass('off')

  setMarkersVisibilityByType:(isVisible, type, cat)->
    for markerTypeObject in @gMarker[cat]["markerGroup"] when markerTypeObject.slug is type
      marker.setVisible(isVisible) for marker in markerTypeObject.markers

  
  setMarkersVisibilityByCat:(isVisible, cat)->
    for markerTypeObject in @gMarker[cat]["markerGroup"]
      marker.setVisible(isVisible) for marker in markerTypeObject.markers

  handleMarkerRemovalTool:(e)=>
    if @removeMarkerLink.hasClass('active')
      @removeMarkerLink.removeClass('active')
      @optionsBox.removeClass('red')
      @canRemoveMarker = false
    else
      @removeMarkerLink.addClass('active')
      @optionsBox.addClass('red')
      @canRemoveMarker = true
      @markerList.removeClass('active')
      @addMarkerLink.removeClass('active')
    
  handleExport:(e)=>
    exportMarkerObject = {}
    for markersCat, markersObjects of @gMarker
      if not exportMarkerObject[markersCat]?
        exportMarkerObject[markersCat] = {}
        exportMarkerObject[markersCat]["name"] = markersObjects.name
        exportMarkerObject[markersCat]["markerGroup"] = []
        
      for markerTypeObject, key in markersObjects.markerGroup
        newmarkerTypeObject = {}
        newmarkerTypeObject["name"] = markerTypeObject.name
        newmarkerTypeObject["slug"] = markerTypeObject.slug
        newmarkerTypeObject["markers"] = []
        exportMarkerObject[markersCat]["markerGroup"].push(newmarkerTypeObject)
        for marker in markerTypeObject.markers
          nm = 
            "lng" : marker.getPosition().lng()
            "lat" : marker.getPosition().lat()
            "title" : marker.title
            "desc"  : marker.desc
          exportMarkerObject[markersCat]["markerGroup"][key]["markers"].push(nm)

    jsonString = JSON.stringify(exportMarkerObject)
    @exportWindow.find('.content').html(jsonString)
    @exportWindow.show();
    
  handleEdition:(e)=>
    this_ = $(e.currentTarget)
    $(elements).removeClass('active') for elements in @editionsTools when elements isnt e.currentTarget
    this_.toggleClass('active')
    @html.removeClass('add remove move send')

    @appState = "read"
    if this_.hasClass('active')
      @appState = this_.attr('id')
      @html.addClass(this_.attr('id'))
    
    if @appState is "read"
      @setDraggableMarker()
    
  getStartLat:()->
    params = extractUrlParams()
    if params['lat']?
        params['lat']
    else
        @defaultLat
    
  getStartLng:()->
      params = extractUrlParams()
      if params['lng']?
          params['lng']
      else
          @defaultLng
    
  removeMarkerFromType:(mType, mCat)->
    confirmMessage = "Delete all «#{mType}» markers on the map?"
    @confirmBox.initConfirmation(confirmMessage, ()=>
      for markerType, typeKey in @gMarker[mCat]["markerGroup"] when markerType.slug is mType
        for marker, markerKey in markerType.markers
          marker.setMap(null)
          @gMarker[mCat]["markerGroup"][typeKey]['markers'] = _.reject(markerType.markers, (m)=>
            return m == marker
          )
    )
  
  removeMarker:(id, mType, mCat)->
    confirmMessage = "Are you sure you want to delete this marker?"
    @confirmBox.initConfirmation(confirmMessage, ()=>
      
      for markerType, typeKey in @gMarker[mCat]["markerGroup"] when markerType.slug is mType
        for marker, markerKey in markerType.markers when marker.__gm_id is id
          marker.setMap(null)
          @gMarker[mCat]["markerGroup"][typeKey]['markers'] = _.reject(markerType.markers, (m)=>
            return m == marker
            # return m.__gm_id == id
          )
          return true
    )
  
  setDraggableMarker:(val)->
    unDrag = (marker)->
      marker.setDraggable(false)
      marker.setCursor('pointer')
      
    for type, markersObjects of @gMarker
      for markerTypeObject, key in markersObjects.markerGroup
        unDrag(marker) for marker in markerTypeObject.markers
        
  toggleMarkerList: (e)=>
    this_ = $(e.currentTarget)
    @markerList.toggleClass('active')
    this_.toggleClass('active')
    if this_.hasClass('active')
      @removeMarkerLink.removeClass('active')
      @optionsBox.removeClass('red')
      @canRemoveMarker = false

  getMarkerByCoordinates:(lat, lng)->
    for type, markersObjects of Markers
      for markerTypeObject, key in markersObjects.markerGroup
        return marker for marker in markerTypeObject.markers when marker.lat is lat and marker.lng is lng
    return false
  
  turnOfMenuIconsFromCat:(markerCat)->
    menu = $(".menu-marker[data-markerCat='#{markerCat}']")
    menu.find('.group-toggling').addClass('off')
    menu.find('.trigger').addClass('off')
  
  addMenuIcons:()->
    markersOptions = $.get('assets/javascripts/templates/markersOptions._', (e)=>
      template = _.template(e);
      html = $(template(Resources))
      
      # Binding click on marker icon in markers option list
      html.find(".trigger").bind 'click', (e) =>
        item           = $(e.currentTarget)
        myGroupTrigger = item.closest(".menu-marker").find('.group-toggling')
        markerType     = item.attr('data-type')
        markerCat      = item.attr('data-cat')
        
        # Binding different action to the click considering @appState
        # read   -> Toggle on/off marker on map
        # add    -> Add a draggable marker on center of map
        # remove -> Delete all marker from clicked marker type
        switch @appState
          when "read", "move"
            if @canToggleMarkers
              if item.hasClass('off')
                @setMarkersVisibilityByType(true, markerType, markerCat)
                item.removeClass('off')
                myGroupTrigger.removeClass('off')
              else
                @setMarkersVisibilityByType(false, markerType, markerCat)
                item.addClass('off')
          when "add"
            coord     = @map.getCenter()
            newMarkerInfo =
              desc      : ""
              title     : ""
              lat       : coord.lat()
              lng       : coord.lng()
              draggable : true
            @addMarker(newMarkerInfo, markerType, markerCat)
          when "remove"
            @removeMarkerFromType(markerType, markerCat)
      
      html.find('.group-toggling').bind 'click', (e)=>
        this_ = $(e.currentTarget)
        parent = this_.closest('.menu-marker')
        markerCat = parent.attr('data-markerCat')
        if this_.hasClass('off')
          this_.removeClass('off')
          @setMarkersVisibilityByCat(on, markerCat)
          parent.find('.trigger').removeClass('off')
        else
          this_.addClass('off')
          @setMarkersVisibilityByCat(off, markerCat)
          parent.find('.trigger').addClass('off')
            
      @markersOptionsMenu.find('.padding').prepend(html)
      @turnOfMenuIconsFromCat(markerCat) for markerCat of Markers when markerCat isnt @defaultCat
    )
      
  initializeAreaSummaryBoxes:()->
    for area of Areas
        @areaSummaryBoxes[area] = new AreaSummary(@map, Areas[area])
        
  setAreasInformationVisibility:(isVisible)->
    for box in @areaSummaryBoxes
        box.setVisible(isVisible)
  toggleMarkersOptionsMenu: () ->
    @markersOptionsMenu.toggleClass('active')
  hideMarkersOptionsMenu: () ->
    @markersOptionsMenu.addClass('off')
  showMarkersOptionsMenu: () ->
    @markersOptionsMenu.removeClass('off')

###
# }}}
###
 
###
# class AreaSummary {{{
###
class AreaSummary
    constructor:(map, area)->
        swBound = new google.maps.LatLng(area.swLat, area.swLng)
        neBound = new google.maps.LatLng(area.neLat, area.neLng)
        @bounds_ = new google.maps.LatLngBounds(swBound, neBound)
        @area_ = area
        @div_ = null
        @height_ = 80
        @width_ = 150
        @template = ""
        $.get('assets/javascripts/templates/areasSummary._', (e)=>
          @template = _.template(e)
          @setMap(map)
        )
    
    AreaSummary:: = new google.maps.OverlayView();
    
    onAdd:()->
        content = @template(@area_)
        @div_ = $(content)[0]
        panes = @getPanes()
        panes.overlayImage.appendChild(@div_)
        @setVisible(false)
        
    draw:()->
      overlayProjection = @getProjection()
      sw = overlayProjection.fromLatLngToDivPixel(this.bounds_.getSouthWest());
      ne = overlayProjection.fromLatLngToDivPixel(this.bounds_.getNorthEast());

      div = this.div_;
      div.style.left = sw.x + ((ne.x - sw.x) - @width_) / 2 + 'px';
      div.style.top = ne.y + ((sw.y - ne.y) - @height_) / 2 + 'px';
    
    setVisible:(isVisible)->
        if @div_
            if isVisible is true
                @div_.style.visibility = "visible"
            else
                @div_.style.visibility = "hidden"
###
# }}}
###                

###
# class AreaSummary {{{
###
class CustomInfoWindow
  constructor: (marker, content, opts) ->
    @content = content
    @marker  = marker
    @map     = marker.map
    @wrap = $('<div class="customInfoWindow"><a href="javascript:" title="Close" class="close button"></a><div class="padding"></div></div>')
    @closeBtn = @wrap.find('.close')
    @setMap(@map)
    @isVisible = false
    @onClose= opts.onClose
    @onOpen= opts.onOpen
    @closeBtn.bind('click', @close)

  CustomInfoWindow:: = new google.maps.OverlayView()
  
  
  onAdd:()->
      @wrap.find('.padding').append(@content)
      @iWidth  = @wrap.outerWidth()
      @iHeight = @wrap.outerHeight()
      @wrap.css(
        position: "absolute"
      )
      panes = @getPanes()
      panes.overlayImage.appendChild(@wrap[0])
      # @open()
  
  draw:()->
    overlayProjection = @getProjection()
    pos = overlayProjection.fromLatLngToDivPixel(@marker.position);
    @leftOffset = pos.x + 30
    @topOffset = pos.y - 80
    @wrap.css(
      left: @leftOffset
      top: @topOffset
    )
  close:()=>
    if @wrap
      @onClose(this)
      @isVisible = false
      @wrap.css(
        visibility : "hidden"
      )
  open:()=>
    if @wrap
      # @panMap()
      @onOpen(this)
      @isVisible = true
      @wrap.css(
        visibility : "visible"
      )
  panMap: () -> 
    
    bounds = @map.getBounds();
    if not bounds then return
  
    # the degrees per pixel
    mapDiv = @map.getDiv();
    mapWidth = mapDiv.offsetWidth;
    mapHeight = mapDiv.offsetHeight;
    boundsSpan = bounds.toSpan();
    longSpan = boundsSpan.lng();
    latSpan = boundsSpan.lat();
    degPixelX = longSpan / mapWidth;
    degPixelY = latSpan / mapHeight;
  
    # The bounds of the map
    mapWestLng = bounds.getSouthWest().lng();
    mapEastLng = bounds.getNorthEast().lng();
    mapNorthLat = bounds.getNorthEast().lat();
    mapSouthLat = bounds.getSouthWest().lat();
  
    # The bounds of the infowindow
    iwWestLng = @marker.position.lng() + (@leftOffset) * degPixelX;
    iwEastLng = @marker.position.lng() + (@leftOffset + @iWidth) * degPixelX;
    iwNorthLat = @marker.position.lat() - (@toptOffset) * degPixelY;
    iwSouthLat = @marker.position.lat() - (@toptOffset + @iHeight) * degPixelY;
  
    # calculate center shift
    
    shiftLng = (iwWestLng < mapWestLng ? mapWestLng - iwWestLng : 0) + (iwEastLng > mapEastLng ? mapEastLng - iwEastLng : 0);
    shiftLat = (iwNorthLat > mapNorthLat ? mapNorthLat - iwNorthLat : 0) + (iwSouthLat < mapSouthLat ? mapSouthLat - iwSouthLat : 0);
    # The center of the map
    center = @map.getCenter();
  
    # The new map center
    centerX = center.lng() - shiftLng;
    centerY = center.lat() - shiftLat;
  
    # center the map to the new shifted center
    console.log "#{centerY}, #{centerX}"
    @map.setCenter(new google.maps.LatLng(centerY, centerX));
  
    # Remove the listener after panning is complete.
    # google.maps.event.removeListener(@.boundsChangedListener_);
    # @.boundsChangedListener_ = null;
###
# }}}
###

extractUrlParams = ()->
    parameters = location.search.substring(1).split('&')
    f = []
    for element in parameters
        x = element.split('=')
        f[x[0]]=x[1]
    f
    
$ ()->
  myCustomMap = new CustomMap('#map')
  markersOptionsMenuToggle = $('#options-toggle strong')
  markersOptionsMenuToggle.click( () ->
    myCustomMap.toggleMarkersOptionsMenu()
  )
