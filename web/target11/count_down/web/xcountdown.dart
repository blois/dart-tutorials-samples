// Some things we need.
import 'package:web_ui/web_ui.dart';
import 'dart:html';
import 'dart:async';
import 'dart:indexed_db';

// Observe timeRemaining.
// Used to format and update each milestone display each second.
@observable String timeRemaining = '';

// Observe errorMsg.
// It displays a message for the user.
@observable String errorMsg = '';

// A class to hold the milestone info.
@observable class Milestone {
  final String name;
  final String dateAndTime;
  String display;
  
  Milestone(this.name, this.dateAndTime, this.display);
  String toString() => this.name + ' ' + this.dateAndTime + ' ' + this.display;
}

class CounterComponent extends WebComponent {

  // These are bound to input elements.
  String newMilestoneName = "New Year's";
  String newMilestoneDate = '2014-01-01';
  String newMilestoneTime = '00:00:00';
  
  // List of milestones to which to count down.
  @observable List<Milestone> milestones = toObservable(new List());
  
  // Fires an event every second to update displays.
  // Is null when no milestones to count.
  Timer timer = null;
  
  // The indexed database to store the milestones.
  // Provided by the window.
  Database indexedDB;
  String storeName = 'countDownStore'; 
  bool idbAvailable = IdbFactory.supported;
  
  // For development.
  bool verbose = true;

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
    if (verbose) print('in addMilestone');
        
    errorMsg = '';
    
    // Make sure milestone name is unique.
    if (milestones.any((e) => e.name == newMilestoneName)) {
      errorMsg = '$newMilestoneName is already in database';
      return;
    }
    
    // Make sure milestone is in the future, and not in the past.
    String str = newMilestoneDate + ' ' + newMilestoneTime;  
    DateTime now = new DateTime.now();
    DateTime milestoneTime = DateTime.parse(str);
    
    if (milestoneTime.isAfter(now)) {
      _addMilestone(newMilestoneName, str);
    } else {
      errorMsg = 'Milestone must be later than now.';
    }
  }
  
  // Called from addMilestone.
  void _addMilestone(String name, String dateAndTime) {
    if (verbose) print('in _addMilestone: $name $dateAndTime');
    
    // Add to database.
    Transaction t = indexedDB.transaction(storeName, 'readwrite');
    t.objectStore(storeName).put(dateAndTime, name) /* It's value first, then key. Who's idea was that? */
    .then((IDBRequest) {
      // Add to internal list.
      milestones.add(new Milestone(name, dateAndTime, name));
      startMilestoneTimer();
    });
  }
  
  // Minus - button click handler.
  // Removes the associated item from the internal list and from the database.
  void removeMilestone(int index) {
    if (verbose) print('in removeMilestone: $index');

    errorMsg = '';
    
    // Remove from database.
    Transaction t = indexedDB.transaction(storeName, 'readwrite');
    t.objectStore(storeName).delete(milestones[index].name)
    .then((IDBRequest) {
      // Remove from internal list.
      milestones.removeAt(index);
      stopMilestoneTimer();
    });
  }
  
  // Clear button click handler.
  // Removes all milestones from the internal list and from the database.
  void clearDatabase() {
    if (verbose) print('in clearDatabase');
    
    errorMsg = '';
    
    // Clear database.
    Transaction t = indexedDB.transaction(storeName, 'readwrite');
    t.objectStore(storeName).clear()
    .then((request) {
      // Clear internal list.
      print('database cleared');
      milestones.clear();
    });
  }
 
  // Show button click handler.
  // Prints the number of milestones currently in the database.
  void showMeTheMoney() {
    if (verbose) print('in showMeTheMoney');
    
    errorMsg = '';
    // Count records in database.
    Transaction t = indexedDB.transaction(storeName, 'readonly');
    t.objectStore(storeName).count()
    .then((count) {
      print(count);
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
    if (verbose) print('in inserted');
    
    window.indexedDB.open('countDownDatabase',
                           version: 1,
                           onUpgradeNeeded: canCreateObjectStore)
      .then((db) {
        indexedDB = db;
        _initializeFromDB();
      });
  }
  
  // Called when opening the database if a new database or a new version is needed.
  canCreateObjectStore(e) {
    indexedDB = e.target.result;
    if (!indexedDB.objectStoreNames.contains(storeName)) {
      indexedDB.createObjectStore(storeName);
    }
  }

  // Called from inserted().
  // Gets all items from the database
  // and adds a milestone to the internal list for each one.
  void _initializeFromDB() {
    if (verbose) print('in _initializeFromDB');
    
    var trans = indexedDB.transaction(storeName, 'readonly');
    var store = trans.objectStore(storeName);
    
    // Get everything in the store.
    store.openCursor(autoAdvance: true)
      .listen((cursor) {
        // Add milestone to the internal list.
        milestones.add(new Milestone(cursor.key, cursor.value, cursor.key));
      },
      onDone: () {
        // Start the timer when all milestones have been read.
        startMilestoneTimer();
        print('Read ${milestones.length} records.');
      });
  }

  /*
   * Timer stuff.
   */
  // Starts the timer if it's not on (timer is null).
  void startMilestoneTimer() {
    if (timer == null) {
      // The timer goes off every second.
      var oneSecond = new Duration(seconds:1);
      timer = new Timer.periodic(oneSecond, updateDisplays);
      print('timer on');
    }
  }
  
  // Turn off the timer if no more milestones to count down.
  // That is, either there are no milestones, or they have all expired.
  void stopMilestoneTimer() {
    if (verbose) print('in stop milestone timer');
    if (timer != null &&
        (milestones.length == 0 ||
         milestones.every((e) => e.display.startsWith('Huzzah')))) {
      timer.cancel();
      timer = null;
      print('timer off');
    }
  }
  
  // Update the display for each milestone.
  void updateDisplays(Timer _) {
    // What time is it now?
    DateTime now = new DateTime.now();

    // For each milestone, figure out how many seconds between now and then...
    for (int i = 0; i < milestones.length; i++) {

      // Skip this milestone, if it has already passed.
      if (milestones[i].display.startsWith('Huzzah')) continue;
      
      // What is the difference between now and milestone in seconds?
      DateTime milestoneTime = DateTime.parse(milestones[i].dateAndTime);
      int secs = milestoneTime.difference(now).inSeconds;
     
      if (secs <= 0) {  // Milestone has JUST occurred.
        timeRemaining = 'Huzzah for ${milestones[i].name}!';
        milestones[i].display = timeRemaining;
        stopMilestoneTimer();
      } else {          // Still counting down...display it.
        // These are observable strings, so web page gets automatically updated.
        timeRemaining = formatDisplayString(secs);
        milestones[i].display = timeRemaining + ' until ${milestones[i].name}';
      } // end if-else
    } // end for loop
  } // end updateDisplays
  
  String formatDisplayString(int secs) {
    // Some constants.
    final int secondsPerDay = 60*60*24;
    final int secondsPerHour = 60*60;

    // Calculate days, hours, and minutes remaining.
    int d=0, h=0, m=0;
    if (secs >= secondsPerDay) { d = secs ~/ secondsPerDay; secs = secs % secondsPerDay; }
    if (secs >= secondsPerHour) { h = secs ~/ secondsPerHour; secs = secs % secondsPerHour; }
    if (secs >= 60) { m = secs ~/ 60; secs = secs % 60; }
    
    // Format individual pieces of the display string.
    String days = (d == 0) ? '' : '$d Days';
    String hours = (h == 0) ? '' : '$h Hours';
    String minutes = (m == 0) ? '' : '$m Minutes';
    String seconds = '$secs Seconds';
    
    return '$days $hours $minutes $seconds';
  }
} // end class
