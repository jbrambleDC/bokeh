_ = require "underscore"
$ = require "jquery"
$$1 = require "bootstrap/dropdown"
{logger} = require "../../core/logging"
Widget = require "../widgets/widget"
p = require "../../core/properties"
{EQ} = require "../../core/layout/solver"

ActionTool = require "../tools/actions/action_tool"
GestureTool = require "../tools/gestures/gesture_tool"
HelpTool = require "../tools/actions/help_tool"
InspectTool = require "../tools/inspectors/inspect_tool"

toolbar_template = require "./toolbar_template"

class ToolBarView extends Widget.View
  template: toolbar_template

  initialize: (options) ->
    super(options)
    @listenTo(@model, 'change', @render)
    @have_rendered = false

  render: () ->
    if @have_rendered
      return
    @have_rendered = true
    @$el.html(@template(@model.attributes))
    @$el.addClass("bk-toolbar-#{@location}")
    @$el.addClass("bk-sidebar")
    @$el.addClass("bk-toolbar-active")
    button_bar_list = @$('.bk-button-bar-list')

    inspectors = @model.get('inspectors')
    button_bar_list = @$(".bk-bs-dropdown[type='inspectors']")
    if inspectors.length == 0
      button_bar_list.hide()
    else
      anchor = $('<a href="#" data-bk-bs-toggle="dropdown"
                  class="bk-bs-dropdown-toggle">inspect
                  <span class="bk-bs-caret"></a>')
      anchor.appendTo(button_bar_list)
      ul = $('<ul class="bk-bs-dropdown-menu" />')
      _.each(inspectors, (tool) ->
        item = $('<li />')
        item.append(new InspectTool.ListItemView({model: tool}).el)
        item.appendTo(ul)
      )
      ul.on('click', (e) -> e.stopPropagation())
      ul.appendTo(button_bar_list)
      anchor.dropdown()

    button_bar_list = @$(".bk-button-bar-list[type='help']")
    _.each(@model.get('help'), (item) ->
      button_bar_list.append(new ActionTool.ButtonView({model: item}).el)
    )

    button_bar_list = @$(".bk-button-bar-list[type='actions']")
    _.each(@model.get('actions'), (item) ->
      button_bar_list.append(new ActionTool.ButtonView({model: item}).el)
    )

    gestures = @model.get('gestures')
    for et of gestures
      button_bar_list = @$(".bk-button-bar-list[type='#{et}']")
      _.each(gestures[et].tools, (item) ->
        button_bar_list.append(new GestureTool.ButtonView({model: item}).el)
      )
    @$el.css({
      position: 'absolute'
      left: @mget('dom_left')
      top: @mget('dom_top')
      width: @model._width._value - @model._whitespace_right._value - @model._whitespace_left._value
      height: @model._height._value - @model._whitespace_bottom._value - @model._whitespace_top._value
      'margin-left': @model._whitespace_left._value
      'margin-right': @model._whitespace_right._value
      'margin-top': @model._whitespace_top._value
      'margin-bottom': @model._whitespace_bottom._value
    })

class ToolBar extends Widget.Model
  type: 'ToolBar'
  default_view: ToolBarView

  initialize: (attrs, options) ->
    super(attrs, options)
    @_init_tools()

  _init_tools: () ->
    gestures = @get('gestures')

    for tool in @get('tools')
      if tool instanceof InspectTool.Model
        inspectors = @get('inspectors')
        inspectors.push(tool)
        @set('inspectors', inspectors)

      else if tool instanceof HelpTool.Model
        help = @get('help')
        help.push(tool)
        @set('help', help)

      else if tool instanceof ActionTool.Model
        actions = @get('actions')
        actions.push(tool)
        @set('actions', actions)

      else if tool instanceof GestureTool.Model
        et = tool.get('event_type')

        if et not of gestures
          logger.warn("ToolBar: unknown event type '#{et}' for tool:
                      #{tool.type} (#{tool.id})")
          continue

        gestures[et].tools.push(tool)
        @listenTo(tool, 'change:active', _.bind(@_active_change, tool))

    for et of gestures
      tools = gestures[et].tools
      if tools.length == 0
        continue
      gestures[et].tools = _.sortBy(tools, (tool) -> tool.get('default_order'))
      if et not in ['pinch', 'scroll']
        gestures[et].tools[0].set('active', true)

  _active_change: (tool) =>
    event_type = tool.get('event_type')
    gestures = @get('gestures')

    # Toggle between tools of the same type by deactivating any active ones
    currently_active_tool = gestures[event_type].active
    if currently_active_tool? and currently_active_tool != tool
      logger.debug("ToolBar: deactivating tool: #{currently_active_tool.type} (#{currently_active_tool.id}) for event type '#{event_type}'")
      currently_active_tool.set('active', false)

    # Update the gestures with the new active tool
    gestures[event_type].active = tool
    @set('gestures', gestures)
    logger.debug("ToolBar: activating tool: #{tool.type} (#{tool.id}) for event type '#{event_type}'")
    return null

  defaults: () ->
    return {
      gestures: {
        pan: {tools: [], active: null}
        tap: {tools: [], active: null}
        doubletap: {tools: [], active: null}
        scroll: {tools: [], active: null}
        pinch: {tools: [], active: null}
        press: {tools: [], active: null}
        rotate: {tools: [], active: null}
      }
      actions: []
      inspectors: []
      help: []
    }

  props: ->
    return _.extend {}, super(), {
      tools:             [ p.Array,    []                     ]
      logo:              [ p.String,   'normal'               ] # TODO (bev)
    }

  get_constraints: () ->
    constraints = super()
    constraints.push(EQ(@_height, -50))
    return constraints

module.exports =
  Model: ToolBar
  View: ToolBarView