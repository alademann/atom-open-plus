"""

$ npm install opener --save
$ npm install isbinaryfile --save
  isbinaryfile@2.0.1 ../node_modules/isbinaryfile
  npm http GET https://registry.npmjs.org/isbinaryfile
  npm http 200 https://registry.npmjs.org/isbinaryfile
"""

path         = require 'path'
fs           = require 'fs'
isBinaryFile = require 'isbinaryfile'
{Range}      = require 'atom'

osOpen = require "opener"


module.exports =
  openPlusView: null
  xikij: null

  filePattern: /[^\s()!$&'"*+,;=]+/g # no spaces or sub-delims from url rfc3986

  activate: (state) ->
    atom.commands.add "atom-workspace", "open-plus:open", => @openPlus()

  deactivate: ->

  serialize: ->

  # open: (filename) ->
  #   if isBinaryFile(filename)
  #
  openFile: (filename) ->
    console.log "filename: #{filename}"

    if not filename
      view = atom.views.getView(atom.workspace)
      return atom.commands.dispatch view, "application:open-file"

    # if url scheme match, let system open the file
    if filename.match /^[a-z][\w\-]+:/
      #console.log "use os opener"
      # scheme!deb http://repository.spotify.com stable non-free

      osOpen = require "opener"
      return osOpen filename

    # remove trailing non-characters
    filename = filename.replace /\W*$/, ''

    # check if there is an encoded position
    opts = {}
    if m = filename.match /(.*?):(\d+)(?::(\d+))?:?$/
      filename = m[1]
      opts.initialLine = parseInt(m[2])
      if m[3]
        opts.initialColumn = parseInt(m[3])

    editor = atom.workspace.getActiveTextEditor()
    absolute = path.dirname(editor.getPath())

    # check file and open it
    @fileCheckAndOpen filename, absolute, editor, opts

    console.log "#{filename} : #{opts}";

  fileCheckAndOpen: (file, absolute, editor, opts) ->
    # have absolute file path able to be used in scope
    absolutePath = absolute
    # if filename is not absolute, make it absolute relative to current dir
    if path.resolve(file) != file
      filename = path.resolve absolute, file
    else
      filename = file
    if not fs.existsSync filename
      # if no extension there, attach extension of current file
      if not path.extname filename
        filename += path.extname editor.getPath()

    #if the file exists
    if fs.existsSync filename
      stat = fs.statSync filename

      if stat.isDirectory()
        #console.log "open directory"
        return atom.open pathsToOpen: [filename]
      else
        if isBinaryFile(filename)
          return osOpen filename

        # in case file already opened, initialLine and initialColumn are not
        # used. so set bufferposition here
        return atom.workspace.open(filename).then (editor) =>
          if opts.initialLine?
            column = opts.initialColumn ? 0
            editor.setCursorBufferPosition [opts.initialLine-1, column]

    #if it does not exist
    else
      if absolute == ""
        atom.confirm
          message: 'File '+ file + ' does not exist'
          detailedMessage: 'Create it?'
          buttons:
            Ok: ->
              absolutePath = path.dirname(editor.getPath())
              absolutePath = absolutePath.split('/').reverse()

              finalPath = path.dirname(editor.getPath())
              finalPath = finalPath.split('/')

              root = file.split('/').shift()

              for aPath in absolutePath
                if aPath == root
                  finalPath.pop()
                  finalPath = finalPath.join('/')
                  newFile = path.resolve finalPath, file
                  atom.workspace.open(newFile, opts)
                  return
                else
                  finalPath.pop()
                  
            Cancel: -> return
        return

      absolute = absolute.split("/")
      absolute.pop()
      absolute = absolute.join("/")
      # console.log filename
      @fileCheckAndOpen file, absolute, editor, opts

  openPlus: ->
    editor = atom.workspace.getActiveTextEditor()

    filePattern = new RegExp @filePattern.source, "g"
    for selection in editor.getSelections()
      #console.log "selection", selection
      range = selection.getBufferRange()

      if range.isEmpty()
        cursor = selection.cursor
        line   = cursor.getCurrentBufferLine()

        col  = cursor.getBufferColumn()
        opts = wordRegex: @filePattern
        start = cursor.getBeginningOfCurrentWordBufferPosition opts
        end   = cursor.getEndOfCurrentWordBufferPosition opts

        range = new Range(start, end)
        text = editor.getTextInBufferRange range

        # if text is no URL
        if not text.match /^[a-z][\w\-]+:/
          if xikij = atom.packages.getActivePackage('atom-xikij')
            xikij = xikij.mainModule
            if m = line.match /^(\s+)[+-]\s(.*)/
              body = xikij.getBody cursor.getBufferRow(), {editor}
              body += "\n" unless body.match /\n$/
              body += m[1] + "  @filepath\n"
              return xikij.request({body}).then (response) =>
                @openFile response.data

        col  = cursor.getBufferColumn()
        opts = wordRegex: @filePattern
        start = cursor.getBeginningOfCurrentWordBufferPosition opts
        end   = cursor.getEndOfCurrentWordBufferPosition opts

        range = new Range(start, end)

      text = editor.getTextInBufferRange range

      marker = editor.markBufferRange range
      editor.decorateMarker marker, type: "highlight", class: "open-plus"

      setTimeout (-> marker.destroy()), 2000

      # cursor was at some whitespace
      text = "" if text.match /\s/

      @openFile text

# ../../atom-xikij/
