// Some things we need.
import 'package:web_ui/web_ui.dart';
import 'dart:html';
import 'dart:async';
import 'dart:indexed_db';
import 'milestone.dart';

// Observe timeRemaining.
// Used to format and update each milestone display each second.
@observable String timeRemaining = '';

// Observe errorMsg.
// It displays a message for the user.
@observable String errorMsg = '';

class CounterComponent extends WebComponent {

  // These are bound to input elements.
  String newMilestoneName = "New Year's";
  String newMilestoneDate = '2014-01-01';
  String newMilestoneTime = '00:00:00';
  
  // Fires an event every second to update displays.
  // Is null when no milestones to count.
  Timer timer = null;
  
  bool idbAvailable = IdbFactory.supported;
  
  MilestoneStore _store = new MilestoneStore();
  
  List<Milestone> get milestones => _store.milestones; 

  /*
   * 
   * Click handlers for various UI buttons.
   * 
   * 
   */
  
  // Plus + button click handler.
  // Does some boundary checking, then calls _addMilestone() to
  // really add a milestone to the internal list and to the database.
  void addMilestone() {
    log('in addMilestone');
        
    errorMsg = '';
  
    String str = newMilestoneDate + ' ' + newMilestoneTime;  
    DateTime milestoneTime = DateTime.parse(str);
  
    // Make sure milestone is in the future, and not in the past.
    if (milestoneTime.isAfter(new DateTime.now())) {
      _addMilestone(newMilestoneName, str);
    } else {
      errorMsg = 'Milestone must be later than now.';
    }
  }
  
  // Called from addMilestone.
  void _addMilestone(String name, String dateAndTime) {
    log('in _addMilestone: $name $dateAndTime');
    
    var parsedTime = DateTime.parse(dateAndTime);
    _store.add(name, parsedTime).then((_) {
      _startMilestoneTimer();
    }, 
    onError: (e) {
      // Assume that write errors are unique key conflicts.
      errorMsg = '$newMilestoneName is already in database';
    });
  }
  
  // Minus - button click handler.
  // Removes the associated item from the internal list and from the database.
  void removeMilestone(int index) {
    log('in removeMilestone: $index');
    
    errorMsg = '';
    
    var milestone = milestones[index];
    _store.remove(milestone).then((_) {
      _stopMilestoneTimer();
    });
  }
  
  // Clear button click handler.
  // Removes all milestones from the internal list and from the database.
  void clear() {
    log('in clear');
    
    errorMsg = '';
    _store.clear();
    
    _stopMilestoneTimer();
  }
 
  // Show button click handler.
  // Prints the number of milestones currently in the database.
  void showMeTheMoney() {
    log('in showMeTheMoney');
    
    errorMsg = '';
    
    _store.count.then((count) {
      print('$count');
    });
    
    // Print milestones from list.
    milestones.forEach((e) { print(e.toString()); });
  }
  
  /*
   * Initialization bizness
   * 
   * Overrides WebComponent inserted() method,
   * Initializes the database connection.
   * Opens the database called 'countDownDatabase'.
   * Creates an object store called 'countDownStore', if upgrade needed.
   * Using version 1 because I can.
   */
  void inserted() {
    log('in inserted');
    
    _store.open().then((_) {
      _startMilestoneTimer();
    });
    return;
  }
  
  /*
   * Timer stuff.
   */
  // Starts the timer if it's not on (timer is null).
  void _startMilestoneTimer() {
    if (timer == null) {
      // The timer goes off every second.
      var oneSecond = new Duration(seconds:1);
      timer = new Timer.periodic(oneSecond, _updateDisplays);
      print('timer on');
    }
  }
  
  // Turn off the timer if no more milestones to count down.
  // That is, either there are no milestones, or they have all expired.
  void _stopMilestoneTimer() {
    log('in stop milestone timer');
    if (timer != null) {
      // Filter out all the elapsed milestones.
      if (milestones.where((m) => !m.elapsed).isEmpty) {
        timer.cancel();
        timer = null;
        print('timer off');  
      }
    }
  }
  
  // Update the display for each milestone.
  void _updateDisplays(Timer _) {
    // What time is it now?
    DateTime now = new DateTime.now();
    
    // For each milestone, figure out how many seconds between now and then...
    for (var milestone in milestones) {
      milestone.updateDisplay(now);
    }
  }
  
} // end class
