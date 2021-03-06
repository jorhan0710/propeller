{{

┌────────────────────────────────────────────┐
│ Experimental Event v1.4                    │
│ Author: Christopher A Varnon               │
│ Created: December 2011, Updated: 03-12-2013│
│ See end of file for terms of use.          │
└────────────────────────────────────────────┘

  Each Experimental Event is an event to be recorded automatically in conjunction with the Experimental Functions object.
  The intent is to streamline the data collection portion of writing an experiment program.
  Experimental Events can be inputs, outputs, manual events, and raw data.
  Inputs can be used with traditional devices such as levers.
  Outputs can be used with food hoppers, lights and other devices.
  Manual events can be used to note other things in the data that are not directly related to an input or output, such as time intervals.
  Raw data is used to record provided data values. This can be used for a variety of digital input, such as temperature sensors.

}}

VAR
  '' Each version of the object has its own variable space, so each event has unique variables.
  BYTE EventType                                                                ' Notes if the event is an input(0), output(1), manual event(2), or raw data(3).
  BYTE EventCode                                                                ' The ID code for the event. Used to quickly note the event in a memory file.
  BYTE EventPin                                                                 ' The pin of an event.
  BYTE EventState                                                               ' If the event is an input, output or manual event, this variable keeps track of the state.

  '' States for input events: 0-off, 1-onset, 2-on, 3-offset                    ' These states are used by experimental event AND experimental functions.
  '' States for outputs and manual events: 1-on, 3-off                          ' Outputs and manual events have a slightly different naming system to work with experimental functions.

  LONG EventCount                                                               ' The number of times the event occurred.
  LONG EventDuration                                                            ' The total duration of an event.
  LONG EventStart                                                               ' The start time of most recent instance of an event.

  '' In case the contacts on an input device produce rapid switching between on and off states, the debounce methods and the following variables are used to produce clean data.
  WORD Debounce                                                                 ' Used for a debounce time for each input.
  LONG InputStart                                                               ' Holds the start value used to debounce an input.
  BYTE DebounceON                                                               ' Notes if a value has been recorded for debouncing the onset of an input.
  BYTE DebounceOFF                                                              ' Notes if a value has been recorded for debouncing the offset of an input.

  LONG QuickStartStack[20]                                                      ' This variable reserves space to launch a cog to monitor the quickstart touch pads.

PUB DeclareInput(Pin,ClockID)
  '' This method declares that activity on a pin should be considered an input.
  '' The method sets up the event and gives it an ID code.
  '' It also saves the address of the experimental clock for later use.
  '' This method should be called before an experiment starts.

  '' Example: lever.declareinput(leverpin,exp.clockID)

  eventtype:=0                                                                  ' Notes the event is an input.
  eventcode:=idcode[index]                                                      ' Set the ID code to the first available code in the IDcode array.
  index++                                                                       ' Increase index so that the previously assigned ID code is no longer available.
  eventpin:=pin                                                                 ' Save the pin to the variable space.
  dira[pin]:=0                                                                  ' Make sure it is an input.
  debounce:=25                                                                  ' Sets the debounce time to a default of 25ms.
  ExpClock:=ClockID                                                             ' Saves the experimental clock address.

PUB Detect
  '' This method detects the state of an input event.
  '' It then updates the eventstate variable, which can be retrieved in a experiment with the event.state method.
  '' These states can be used by contingencies.
  '' There are four possible states: 0-off, 1-onset, 2-on, and 3-offset.
  '' For example, if the lever.state is an onset, then provide reinforcement.

  '' This method needs to be called in the main experiment loop to detect the input on each program cycle.
  '' It is intended to be used with the experimental functions record method to save data.
  '' Alternate methods are available if debouncing is not needed and for inputs with inverted signals.

  '' Example use in a program for detecting an event without recording data:
  ''    repeat
  ''      input1.detect

  '' Example use in a program for detecting an event and recording data:
  ''    repeat
  ''      exp.record(input1.detect, input1.ID, exp.time(start))

  '' A debounce feature ensures that a device is active for a minimum amount of time (default 25ms) before recording the input as on.
  '' Similarly, the device must be deactivated for the same amount of time before recording the input as off.
  '' This is used to prevent electromechanical issues, such as sparks jumping between contacts on a switch, from creating error in the data.
  '' The debounce code is not 100% effective. It is still possible to cause errors during deliberate attempts.
  '' In other cases ,if the data file reports onsets with no offsets, or offsets with no onsets, bad wiring is likely at fault.
  '' The debounce code controls for most errors, but not all.

  if ina[eventpin]==1                                                           ' If there is input on the pin.
    debounceoff:=0                                                              ' Reset debounceoff.

    if eventstate==2                                                            ' If the state is on.
      return eventstate                                                         ' Return eventstate. No need to debounce.

    elseif eventstate==3                                                        ' If the state is an offset - can be caused by a spark jumping between contacts.
      eventstate:=1                                                             ' Then it is now an onset.
      return eventstate                                                         ' Return eventstate.

    elseif eventstate==0 or eventstate==1                                       ' If the state is off or an onset.
      if debounceon==0                                                          ' If no debounceon time has been set.
        inputstart:=clocktime                                                   ' Then the input starts now.
        debounceon:=1                                                           ' Note that debounceon has been set.
        return eventstate                                                       ' Return the input state, without considering current input activity.

      elseif debounceon==1                                                      ' If debounceon has already been started.
        if clocktime=>inputstart+debounce                                       ' If the time now is greater than the time when the input started plus the debounce time.
          return detect_nodebounce                                              ' Run the detect method, and return the results.
        return eventstate                                                       ' Return the input state, without considering current input activity.


  elseif ina[eventpin]==0                                                       ' If there no input on the pin.
    debounceon:=0                                                               ' Reset debounceon.

    if eventstate==0                                                            ' If the state is off.
      return eventstate                                                         ' Return eventstate. No need to debounce.

    elseif eventstate==1                                                        ' If the state is an onset - can be caused by a spark jumping between contacts.
      eventstate:=3                                                             ' Then it is now an offset.
      return eventstate                                                         ' Return eventstate.

    elseif eventstate==2 or eventstate==3                                       ' If the state is on or an offset.
      if debounceoff==0                                                         ' If no debounceoff time has been set.
        inputstart:=clocktime                                                   ' Then the input starts now.
        debounceoff:=1                                                          ' Note that debounceoff has been set.
        return eventstate                                                       ' Return the input state, without considering current input activity.

      elseif debounceoff==1                                                     ' If debounceoff has already been started.
        if clocktime=>inputstart+debounce                                       ' If the time now is greater than the time when the input started plus the debounce time.
          return detect_nodebounce                                              ' Run the next detect method, and return the results.
        return eventstate                                                       ' Return the input state, without considering current input activity.

PUB DetectInverted
  '' This method is identical to detect except that it works with inputs that are inverted.
  '' Use this when the hardware inverts the signal of the input so that 1 = off and 0 = on.
  '' For example, the Parallax digital I/O board inverts inputs when using the parallel interface.
  '' Current flows when the inputs are off, and stops flowing when the inputs are on.

  if ina[eventpin]==0                                                           ' If there is input on the pin.
    debounceoff:=0                                                              ' Reset debounceoff.

    if eventstate==2                                                            ' If the state is on.
      return eventstate                                                         ' Return eventstate. No need to debounce.

    elseif eventstate==3                                                        ' If the state is an offset - can be caused by a spark jumping between contacts.
      eventstate:=1                                                             ' Then it is now an onset.
      return eventstate                                                         ' Return eventstate.

    elseif eventstate==0 or eventstate==1                                       ' If the state is off or an onset.
      if debounceon==0                                                          ' If no debounceon time has been set.
        inputstart:=clocktime                                                   ' Then the input starts now.
        debounceon:=1                                                           ' Note that debounceon has been set.
        return eventstate                                                       ' Return the input state, without considering current input activity.

      elseif debounceon==1                                                      ' If debounceon has already been started.
        if clocktime=>inputstart+debounce                                       ' If the time now is greater than the time when the input started plus the debounce time.
          return detectinverted_nodebounce                                      ' Run the detect method, and return the results.
        return eventstate                                                       ' Return the input state, without considering current input activity.


  elseif ina[eventpin]==1                                                       ' If there no input on the pin.
    debounceon:=0                                                               ' Reset debounceon.

    if eventstate==0                                                            ' If the state is off.
      return eventstate                                                         ' Return eventstate. No need to debounce.

    elseif eventstate==1                                                        ' If the state is an onset - can be caused by a spark jumping between contacts.
      eventstate:=3                                                             ' Then it is now an offset.
      return eventstate                                                         ' Return eventstate.

    elseif eventstate==2 or eventstate==3                                       ' If the state is on or an offset.
      if debounceoff==0                                                         ' If no debounceoff time has been set.
        inputstart:=clocktime                                                   ' Then the input starts now.
        debounceoff:=1                                                          ' Note that debounceoff has been set.
        return eventstate                                                       ' Return the input state, without considering current input activity.

      elseif debounceoff==1                                                     ' If debounceoff has already been started.
        if clocktime=>inputstart+debounce                                       ' If the time now is greater than the time when the input started plus the debounce time.
          return detectinverted_nodebounce                                      ' Run the next detect method, and return the results.
        return eventstate                                                       ' Return the input state, without considering current input activity.

PUB Detect_NoDebounce
  '' This method detects the state of an input event.
  '' It then updates the eventstate variable, which can be retrieved in a experiment with the event.state method.
  '' These states can be used by contingencies.
  '' There are four possible states: 0-off, 1-onset, 2-on, and 3-offset.
  '' For example, if the lever.state is an onset, then provide reinforcement.

  '' This method needs to be called in the main experiment loop to detect the input on each program cycle.
  '' It is intended to be used with the experimental functions record method to save data.
  '' Alternate methods are available if debouncing is not needed and for inputs with inverted signals.

  '' Example use in a program for detecting an event without recording data:
  ''    repeat
  ''      input1.detect

  '' Example use in a program for detecting an event and recording data:
  ''    repeat
  ''      exp.record(input1.detect, input1.ID, exp.time(start))

  '' No debouncing is used in this method, use only when the device is well tested and reliable.
  '' Note that the detect method uses this method after debouncing is complete.

  if ina[eventpin]==1                                                           ' If there is currently input on the pin.
    if eventstate==0                                                            ' If it was off on the last loop.
      eventstate:=1                                                             ' Then it is now an onset.
      eventstart:=clocktime                                                     ' Record the time of the onset.
      eventcount++                                                              ' It is also a new instance of the event. so increase the event count.
    elseif eventstate==1                                                        ' If it was an onset on the last loop.
      eventstate:=2                                                             ' Then it is now on.
    elseif eventstate==3                                                        ' If the input was an offset last loop but was never set to off - this can occur if a spark jumps between contacts on the input device.
      eventstate:=1                                                             ' Then it is now an onset.

  elseif ina[eventpin]==0                                                       ' If there is not currently input on the pin.
    if eventstate==2                                                            ' If it was on the last loop.
      eventstate:=3                                                             ' Then now it is an offset.
      eventduration+=clocktime-eventstart                                       ' Add the duration of the event to the total duration.
    elseif eventstate==3                                                        ' If it was an offset on the last loop,
      eventstate:=0                                                             ' Then now it is off.
    elseif eventstate==1                                                        ' If the input was an offset last loop but was never set to on - this can occur if a spark jumps between contacts on the input device.
      eventstate:=3                                                             ' Then it is now an offset.

  return eventstate                                                             ' Returns state to be detected the next loop and to be used by contingencies.

PUB DetectInverted_NoDebounce
  '' This method is identical to detect_nodebounce except that the input is inverted.
  '' Use this when the hardware inverts the signal of the input so that 1 = off and 0 = on.
  '' For example, the Parallax digital I/O board inverts inputs when using parallel interface.
  '' Current flows when the inputs are off, and stops flowing when the inputs are on.

  if ina[eventpin]==0                                                           ' If there is currently input on the pin.
    if eventstate==0                                                            ' If it was off on the last loop.
      eventstate:=1                                                             ' Then it is now an onset.
      eventstart:=clocktime                                                     ' Record the time of the onset.
      eventcount++                                                              ' It is also a new instance of the event, so increase the event count.
    elseif eventstate==1                                                        ' If it was an onset on the last loop.
      eventstate:=2                                                             ' Then it is now on.
    elseif eventstate==3                                                        ' If the input was an offset last loop but was never set to off - this can occur if a spark jumps between contacts on the input device.
      eventstate:=1                                                             ' Then it is now an onset.

  elseif ina[eventpin]==1                                                       ' If there is not currently input on the pin,
    if eventstate==2                                                            ' If it was on the last loop.
      eventstate:=3                                                             ' Then now it is an offset.
      eventduration+=clocktime-eventstart                                       ' Add the duration of the event to the total duration.
    elseif eventstate==3                                                        ' If it was an offset on the last loop.
      eventstate:=0                                                             ' Then now it is off.
    elseif eventstate==1                                                        ' If the input was an offset last loop but was never set to on - this can occur if a spark jumps between contacts on the input device.
      eventstate:=3                                                             ' Then it is now an offset.

  return eventstate                                                             ' Returns state to be detected the next loop and to be used by contingencies.

PUB SetDebounce(Time)
  '' This method allows the user to modify the debounce time.
  '' Default value is 25ms, the maximum value is 60,000ms, or 1 minute.
  '' The greater the debounce time, the less accurate the data.
  '' If no debouncing is required use detect_nodebounce in place of detect.

  debounce:=time                                                                ' Set debounce to user provided time interval.

PUB DeclareQuickStart(Pin,ClockID)
  '' This method declares that activity on a QuickStart touch pad should be considered an input.
  '' The method sets up the event, and gives it a ID code.
  '' It also saves the address of the experimental clock for later use.
  '' It should be called before an experiment starts.

  '' Example: lever.declarequickstart(quickstartpin,exp.clockID)

  '' QuickStart pads are not true buttons, so some extra computations are required.
  '' A new cog is launched to perform these computations. Only one cog is launched for the entire quickstart.
  '' Due to the sensitive nature of the touchpads, they are better used for demonstrations, not actual experiments.

  declareinput(pin,clockID)                                                     ' Declares that the pin is an input.

  Case pin                                                                      ' Check to see which quickstart pin is being used.
    7: QuickStartPads|= %10000000                                               ' Add 1 to the pin 7 slot of QuickStartPads.
    6: QuickStartPads|= %01000000                                               ' Add 1 to the pin 6 slot of QuickStartPads.
    5: QuickStartPads|= %00100000                                               ' Add 1 to the pin 5 slot of QuickStartPads.
    4: QuickStartPads|= %00010000                                               ' Add 1 to the pin 4 slot of QuickStartPads.
    3: QuickStartPads|= %00001000                                               ' Add 1 to the pin 3 slot of QuickStartPads.
    2: QuickStartPads|= %00000100                                               ' Add 1 to the pin 2 slot of QuickStartPads.
    1: QuickStartPads|= %00000010                                               ' Add 1 to the pin 1 slot of QuickStartPads.
    0: QuickStartPads|= %00000001                                               ' Add 1 to the pin 0 slot of QuickStartPads.

  if QuickCog==0                                                                ' If the QuickStartCog has not been launched yet.
    QuickCog:=1                                                                 ' Note that it has been launched.
    cognew(QuickStartCog, @QuickStartStack)                                     ' Launch the QuickStartCog.

PUB DetectQuickStart | PadState
  '' This method detects the state of a QuickStart touch pad.
  '' This method detects the state of an input event.
  '' It then updates the eventstate variable, which can be retrieved in a experiment with the event.state method.
  '' These states can be used by contingencies.
  '' There are four possible states: 0-off, 1-onset, 2-on, and 3-offset.
  '' For example, if the lever.state is an onset, then provide reinforcement.

  '' This method needs to be called in the main experiment loop to detect the input on each program cycle.
  '' It is intended to be used with the experimental functions record method to save data.
  '' Alternate methods are available if debouncing is not needed and for inputs with inverted signals.

  '' Example use in a program for detecting an event without recording data:
  ''    repeat
  ''      input1.detectquickstart

  '' Example use in a program for detecting an event and recording data:
  ''    repeat
  ''      exp.record(input1.detectquickstart, input1.ID, exp.time(start))

  Case Eventpin
    7: PadState:=QuickStartState & %10000000                                    ' If the pin is 7, return 10000000 or 00000000.
    6: PadState:=QuickStartState & %01000000                                    ' If the pin is 6, return 01000000 or 00000000.
    5: PadState:=QuickStartState & %00100000                                    ' If the pin is 5, return 00100000 or 00000000.
    4: PadState:=QuickStartState & %00010000                                    ' If the pin is 4, return 00010000 or 00000000.
    3: PadState:=QuickStartState & %00001000                                    ' If the pin is 3, return 00001000 or 00000000.
    2: PadState:=QuickStartState & %00000100                                    ' If the pin is 2, return 00000100 or 00000000.
    1: PadState:=QuickStartState & %00000010                                    ' If the pin is 1, return 00000010 or 00000000.
    0: PadState:=QuickStartState & %00000001                                    ' If the pin is 0, return 00000001 or 00000000.

  if PadState>0                                                                 ' If the PadState is greater than 0.
    PadState:=0                                                                 ' The input must be off, set PadState to 0.
  else                                                                          ' If the PadState is 0.
    PadState:=1                                                                 ' The input must be on, set PadState to 1.

  '' Combined debounce and detect method.
  if PadState==1                                                                ' If there is input on the pad.
    debounceoff:=0                                                              ' Reset debounceoff.

    if eventstate==2                                                            ' If the state is on.
      return eventstate                                                         ' Return eventstate. No need to debounce.

    elseif eventstate==3                                                        ' If the state is an offset - can be caused by a spark jumping between contacts.
      eventstate:=1                                                             ' Then it is now an onset.
      return eventstate                                                         ' Return eventstate.

    elseif eventstate==0 or eventstate==1                                       ' If the state is off or an onset.
      if debounceon==0                                                          ' If no debounceon time has been set.
        inputstart:=clocktime                                                   ' Then the input starts now.
        debounceon:=1                                                           ' Note that debounceon has been set.
        return eventstate                                                       ' Return the input state, without considering current input activity.

      elseif debounceon==1                                                      ' If debounceon has already been started.
        if clocktime=>inputstart+debounce                                       ' If the time now is greater than the time when the input started plus the debounce time.
          if eventstate==0                                                      ' If it was off on the last loop.
            eventstate:=1                                                       ' Then it is now an onset.
            eventstart:=clocktime                                               ' Record the time of the onset.
            eventcount++                                                        ' It is also a new instance of the event, so increase the event count.
          elseif eventstate==1                                                  ' If it was an onset on the last loop.
            eventstate:=2                                                       ' Then it is now on.
        return eventstate                                                       ' Return the input state, without considering current input activity.


  elseif PadState==0                                                            ' If there no input on the pad.
    debounceon:=0                                                               ' Reset debounceon.

    if eventstate==0                                                            ' If the state is off.
      return eventstate                                                         ' Return eventstate. No need to debounce.

    elseif eventstate==1                                                        ' If the state is an onset - can be caused by a spark jumping between contacts.
      eventstate:=3                                                             ' Then it is now an offset.
      eventduration+=clocktime-eventstart                                       ' Add the duration of the event to the total duration.
      return eventstate                                                         ' Return eventstate.

    elseif eventstate==2 or eventstate==3                                       ' If the state is on or an offset.
      if debounceoff==0                                                         ' If no debounceoff time has been set.
        inputstart:=clocktime                                                   ' Then the input starts now.
        debounceoff:=1                                                          ' Note that debounceoff has been set.
        return eventstate                                                       ' Return the input state, without considering current input activity.

      elseif debounceoff==1                                                     ' If debounceoff has already been started.
        if clocktime=>inputstart+debounce                                       ' If the time now is greater than the time when the input started plus the debounce time.
          if eventstate==2                                                      ' If it was on the last loop.
            eventstate:=3                                                       ' Then now it is an offset.
          elseif eventstate==3                                                  ' If it was an offset on the last loop.
            eventstate:=0                                                       ' Then now it is off.
        return eventstate                                                       ' Return the input state, without considering current input activity.

PUB AdjustQuickStartSensitivity(value)
  '' Adjusts the sensitivity of the QuickStart touch pads.
  '' Sensitivity is a global value. It effects every touch pad.
  '' Sensitivity only needs to be adjusted for one event to effect every touch pad.
  '' Variations in humidity and other conditions may require adjustments in sensitivity.
  '' Values between 250 and 750 work well in most situations.
  '' The default value is 500.

  Sensitivity:=Value

PRI QuickStartCog
  '' This method checks the state of QuickStart touch pads.
  '' It only detects the Pads that are declared as inputs.

  repeat
    dira[7..0]:=QuickStartPads                                                  ' Set the pads to outputs.
    outa[7..0]:=QuickStartPads                                                  ' Charge the pads.
    dira[7..0]:=%00000000                                                       ' Set the pads to inputs.
    waitcnt(clkfreq/10000*sensitivity+cnt)                                      ' Wait to detect inputs.
    QuickStartState:=ina[7..0]                                                  ' Save the state of the inputs.

PUB DeclareOutput(Pin,ClockID)
  '' This method declares an output event on a pin that will be recorded during the experiment.
  '' This is used to turn on and off outputs during the experiment and automatically record the data.

  '' The method sets up the event, and gives it a ID code.
  '' It also saves the address of the experimental clock for later use.
  '' It should be called before an experiment starts.

  '' Example: lever.declareoutput(lightpin,exp.clockID)

  eventtype:=1                                                                  ' Notes the event is an output.
  eventcode:=idcode[index]                                                      ' Set the ID code to the first available code in the IDcode array.
  index++                                                                       ' Increase index so that the previously assigned ID code is no longer available.
  eventstate:=3                                                                 ' Sets the event state to off.
  eventpin:=pin                                                                 ' Saves the pin to variable space.
  dira[pin]:=1                                                                  ' Makes sure it is an output.
  ExpClock:=ClockID                                                             ' Saves the experimental clock address.

PUB TurnOn
  '' Turns on an output.
  '' Does nothing if it is already on.
  '' Use within an experimental functions.record to save data.

  '' Example use in a program, a light is turned on when a lever is pressed
  ''    repeat
  ''      exp.record(lever.detect, lever.ID, exp.time(start))
  ''      if lever.state==1
  ''        exp.record(light.turnon, light.ID, exp.time(start))

  If eventstate <> 1                                                            ' As long as the event state isn't 1 or ON.
    eventstate:=1                                                               ' Set the event state to ON.
    outa[eventpin]:=1                                                           ' Turn the output on.
    eventstart:=clocktime                                                       ' Record the time of the onset.
    eventcount++                                                                ' Notes the instance.

  return eventstate                                                             ' Returns the event state.

PUB TurnOff
  '' Turns off an output.
  '' Does nothing if it is already off.
  '' Use within an experimental functions.record to save data.

  '' Example use in a program, shock turned off when a lever is pressed
  ''    repeat
  ''      exp.record(lever.detect, lever.ID, exp.time(start))
  ''      if lever.state==1
  ''        exp.record(shock.turnoff, shock.ID, exp.time(start))

  If eventstate <> 3                                                            ' As long as the event state isn't 3 or OFF.
    eventstate:=3                                                               ' Set the event state to OFF.
    outa[eventpin]:=0                                                           ' Turn the output off.
    eventduration+=clocktime-eventstart                                         ' Add the duration of the event to the total duration.

  return eventstate                                                             ' Returns the event state.

PUB DeclareManualEvent(ClockID)
  '' This method declares a manual event that is not related to an input or output.
  '' This is used to automatically note occurrences of events.
  '' It also saves the address of the experimental clock for later use.
  '' It should be called before an experiment starts.

  '' This type of event can be started or stopped for any reason.
  '' It is not effected by inputs, nor does it control outputs.

  eventtype:=2                                                                  ' Notes the event is a manual event.
  eventcode:=idcode[index]                                                      ' Set the ID code to the first available code in the IDcode array.
  index++                                                                       ' Increase index so that the previously assigned ID code is no longer available.
  eventstate:=3                                                                 ' Sets the event state to off.
  ExpClock:=ClockID                                                             ' Saves the experimental clock address.

PUB StartManualEvent
  '' Starts recording a manual event.
  '' Does nothing if it is already on.
  '' Use within an experimental functions.record to save data.

  If eventstate <> 1                                                            ' As long as the event state isn't 1 or ON.
    eventstate:=1                                                               ' Turn the event state ON.
    eventstart:=clocktime                                                       ' Record the time of the onset.
    eventcount++                                                                ' Notes the instance.

  return eventstate                                                             ' Returns the event state.

PUB StopManualEvent
  '' Stops recording a manual event.
  '' Does nothing if it is already off.
  '' Use within an experimental functions.record to save data.

  If eventstate <> 3                                                            ' As long as the event state isn't 3 or OFF
    eventstate:=3                                                               ' Turn the event state OFF.
    eventduration+=clocktime-eventstart                                         ' Add the duration of the event to the total duration.

  return eventstate                                                             ' Returns the event state.

PUB DeclareRawData(ClockID)
  '' This method declares that the event will be used to save some form of raw data.
  '' The raw data can be used to store a variety of information like temperature or light levels.
  '' The primary purpose of declaring an experimental event object as raw data is to automatically generate an ID code to save data.

  '' The method sets up the event, and gives it a ID code.
  '' It also saves the address of the experimental clock for later use.
  '' It should be called before an experiment starts.

  '' Example: thermometor.declarerawdata(exp.clockID)

  eventtype:=3                                                                  ' Notes the event is raw data.
  eventcode:=idcode[index]                                                      ' Set the ID code to the first available code in the IDcode array.
  index++                                                                       ' Increase index so that the previously assigned ID code is no longer available.
  ExpClock:=ClockID                                                             ' Saves the experimental clock address. - Unused for raw data.

PUB State
  '' Returns the event state.
  '' It can be used for inputs if a detect method has already been called.
  '' It can be used at any time for outputs and manual events.
  '' The state can be used for contingencies.
  '' For example if a red light is on, then provide reinforcement for each key peck.

  '' Example code:
  ''    repeat
  ''      exp.record(key.detect, key.ID, exp.time(start))
  ''      if key.state==1 and redlight.state==1
  ''        provide reinforcement

  return eventstate

PUB ID
  '' Returns the event ID.
  '' This is only used for saving data.

  return eventcode

PUB Count
  '' Returns the event count.
  '' This is can be used in contingencies.
  '' For example, in an FR10 program if the lever.count == 10, then provide reinforcement.

  return eventcount

PUB SetCount(NewCount)
  '' Changes the event count.
  '' This can be used for a variety of purposes.
  '' For example, setting the count to 0 after each reinforcer in an FR program allows the count method to easily keep track of the number of responses required for a reinforcer.

  eventcount:=newcount

PUB Duration
  '' Returns the total duration of an event.
  '' This includes any ongoing event such as a button that is currently being pressed.
  '' The total duration can be used in contingencies.
  '' Individual event duration can be created and used in contingencies by setting the duration to 0 after each instance.

  case eventtype                                                                ' Note the event type.
    0:                                                                          ' If the event is an input.
      if eventstate==0                                                          ' If the input is off.
        return eventduration                                                    ' Return the last recorded duration.
      else                                                                      ' If the event is an onset, on, or an offset.
        return eventduration+(clocktime-eventstart)                             ' Return the last duration plus the duration of the current instance.
    1,2:                                                                        ' If the event is an output or a manual event.
      if eventstate==1                                                          ' If the event is on.
        return eventduration+(clocktime-eventstart)                             ' Return the last duration plus the duration of the current instance.
      else                                                                      ' If the event is off.
        return eventduration                                                    ' Return the last recorded duration.
    3:                                                                          ' If the event is raw data.
      return 0                                                                  ' Return 0. No duration can be calculated.

PUB SetDuration(NewDuration)
  '' Changes the event duration.
  '' Setting the duration to 0 after each response will allow the duration method to return individual event duration.

  eventduration:=newduration

PRI ClockTime
  '' This method returns the time of the clock in experimental functions.
  '' It is used to debounce inputs and record event duration.

  return long[expclock]                                                         ' Return the long value found at the address noted by expclock.

DAT
'' DAT space is the same among all instances of an object, while variable space is unique.
'' This means that each experimental event shares the information in the DAT space.

'' The ExpClock stores the address of experimental functions's clock. This is used for debouncing inputs.
ExpClock                Word 0

'' 203 Event ID codes are available. This means that 203 separete events can be recorded.
IDCode                  Byte   33, 34, 35, 36, 37, 38, 39, 42, 43, 45, 47, 58, 59, 60, 61, 62, 63, 64, 65, 66
                        Byte   67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86
                        Byte   87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99,100,101,102,103,104,105,106
                        Byte  107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126
                        Byte  128,129,130,131,132,133,134,135,136,137,138,140,141,142,143,144,145,146,147,148
                        Byte  149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168
                        Byte  169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188
                        Byte  189,190,191,192,193,194,195,196,197,198,199,200,201,203,204,205,206,207,208,209
                        Byte  210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,228,229,230,231
                        Byte  232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251
                        Byte  252,253,254

'' Index for which ID code is to be used by next declared event.
'' This allows all experimental events to know which IDs are taken.
Index                   Byte 0

'' QuickCog is set to 1 if a cog is launched to detect input on the QuickStart touchpads.
QuickCog                Byte 0

'' QuickCog is set to 1 if a cog is launched to detect input on the QuickStart touchpads.
Sensitivity             Word 500

'' Used to indicate which QuickStart pads are going to be used as inputs.
QuickStartPads          Byte %00000000

'' Used to contain the state of the QuickStart pads.
QuickStartState         Byte %00000000

DAT
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}
