ns = @edsc.models.ui

ns.Temporal = do (ko, dateUtil=@edsc.util.date, stringUtil = @edsc.util.string) ->

  current_year = new Date().getUTCFullYear()

  class TemporalDate
    constructor: (@defaultYear, @isRecurring) ->
      @date = ko.observable(null)
      @year = ko.observable(@defaultYear)

      @year.subscribe (year) =>
        if @isRecurring()
          date = @date()
          if date?
            date.setUTCFullYear(year)
            @date(new Date(date.getTime()))


      @humanDateString = ko.computed
        read: =>
          if @date()?
            dateStr = dateUtil.isoUtcDateTimeString(@date())
            dateStr = dateStr.substring(5) if @isRecurring()
            dateStr
          else
            ""
        write: (dateStr) =>
          if dateStr?.length > 0
            dateStr = "#{@year()}-#{dateStr}" if @isRecurring()
            @date(new Date(dateStr.replace(' ', 'T') + 'Z'))
          else
            @date(null)

      @dayOfYearString = ko.computed
        read: =>
          date = @date()
          if date?
            "#{date.getUTCFullYear()}-#{stringUtil.padLeft(@dayOfYear(), '0', 3)}"
          else
            ""

        write: (dayStr) =>
          match = /(\d{4})-(\d{3})/.exec(dayStr)
          unless match
            @date(null)
            return
          year = parseInt(match[1], 10)
          day = parseInt(match[2], 10)
          date = new Date(Date.UTC(year, 0, day))
          unless date.getUTCFullYear() is year # Date is higher than the number of days in the year
            @date(null)
            return
          @date(date)

      @dayOfYear = ko.computed =>
        date = @date()
        if date?
          one_day = 1000 * 60 * 60 * 24
          year = 2007 # Sunday is January 1st, not a leap year
          #year = 2012 # Sunday is January 1st, leap year
          start_day = Date.UTC(year, 0, 0)
          end_day = Date.UTC(year, date.getUTCMonth(), date.getUTCDate())
          result = Math.floor((end_day - start_day) / one_day)
          result
        else
          null

      @queryDateString = ko.computed =>
        if @date()
          @date().toISOString()
        else
          null

    fromJson: (jsonObj) ->
      @date(new Date(jsonObj.date))
      @year(jsonObj.year)

    serialize: ->
      {
        date: @date()?.getTime(),
        year: @year()
      }

    copy: (other) ->
      @date(other.date())
      @year(other.year())
      @isRecurring(other.isRecurring())

    clear: =>
      @date(null)
      @year(@defaultYear)

  class TemporalCondition
    constructor: (@query) ->
      @isRecurring = ko.observable(false)
      @start = new TemporalDate(1960, @isRecurring)
      @stop = new TemporalDate(current_year, @isRecurring)

      @queryCondition = ko.computed(@_computeQueryCondition)

      @years = ko.computed(@_computeYears())
      @yearsString = ko.computed => @years().join(' - ')

    fromJson: (jsonObj) ->
      @isRecurring(jsonObj.isRecurring)
      @start.fromJson(jsonObj.start)
      @stop.fromJson(jsonObj.stop)

    serialize: ->
      {
        isRecurring: @isRecurring()
        start: @start.serialize()
        stop: @start.serialize()
      }

    copy: (other) ->
      @start.copy(other.start)
      @stop.copy(other.stop)
      @isRecurring(other.isRecurring())

    clear: =>
      @start.clear()
      @stop.clear()

    _computeYears: =>
      read: =>
        if @isRecurring()
          [@start.year(), @stop.year()]
        else
          []
      write: (values) =>
        @start.year(values[0])
        @stop.year(values[1])

    _computeQueryCondition: =>
      start = @start
      stop = @stop

      return null unless start.date()? || stop.date()?

      result = [start.queryDateString(), stop.queryDateString()]

      result = result.concat(start.dayOfYear(), stop.dayOfYear()) if @isRecurring()

      result.join(',')

  class Temporal
    constructor: (@query) ->
      @applied = new TemporalCondition()
      @pending = new TemporalCondition()
      @query.temporal(@applied)

      # Clear temporal when switching types
      @pending.isRecurring.subscribe => @pending.clear()

    apply: =>
      @applied.copy(@pending)

  exports = Temporal