import 'package:web_ui/web_ui.dart';
import 'dart:html';
import 'dart:async';
import 'dart:indexed_db';

// Observe timeRemaining. Used to update each milestone display each second.
@observable String timeRemaining = '';

// Observe msg. It displays a message for the user.
@observable String msg = '';

// A class to hold the milestone info.
@observable class Milestone {
  String name;
  String dateAndTime;
  String display;
  
  Milestone(this.name, this.dateAndTime, this.display);
  String toString() => this.name + ' ' + this.dateAndTime + ' ' + this.display;
}

class CounterComponent extends WebComponent {

  // Bind-values for input elements.
  String newMilestoneName = "New Year's";
  String newMilestoneDate = '2014-01-01';
  String newMilestoneTime = '00:00:00';
  
  // List of milestones to which to count down
  // XX: should probably have a specialized list to override contains();
  @observable List<Milestone> milestones = toObservable(new List());
  
  // Fires an event every second to update displays.
  // Is null when no milestones to count.
  Timer timer = null;
  
  // The indexed database to store the countdown timers. Provided by the window.
  Database indexedDB;
  String storeName = 'newcountdown'; // the name 
  int dbVersion;
  
  bool idbAvailable = IdbFactory.supported;

  /*
   * Initializes the database connection.
   * Opens the database called 'myAwesomeDatabase'.
   * Creates an object store called 'newcountdown'.
   * Using version 7 because I can.
   */
  // Overrides WebComponent inserted() method,
  // XX: is there a super.inserted() that I should be calling?
  inserted() {
    if (!idbAvailable) return;

    // Open the Database.
    window.indexedDB.open('myAwesomeDatabase', version: 7,
        onUpgradeNeeded: (e) {
          indexedDB = e.target.result;
          if (!indexedDB.objectStoreNames.contains(storeName)) {
            indexedDB.createObjectStore(storeName);
          }
        })
        .then((db) {
          indexedDB = db;
          initializeFromDB();
          return true; // XX: why am I returning true here?
        });
  }

  // Called from inserted(), gets all items from the database
  // and adds a milestone to the internal list for each one.
  void initializeFromDB() {
    var trans = indexedDB.transaction(storeName, 'readonly');
    var store = trans.objectStore(storeName);
    // Get everything in the store.
    store.openCursor(autoAdvance: true)
      .listen((cursor) {
        milestones.add(new Milestone(cursor.key, cursor.value, cursor.key));
        startMilestoneTimer();
      });
  }

  /*
   * Click handlers for various UI buttons.
   */
  
  // Show button click handler.
  // Prints the number of milestones currently in the database.
  void showMeTheMoney() {
    if (!idbAvailable) return;
    
    Transaction t = indexedDB.transaction(storeName, 'readonly');
    t.objectStore(storeName).count()
    .then((count) {
      print(count);
    });
    milestones.forEach((e) { print(e.toString()); });
    msg = '';
  }
  
  // Clear button click handler.
  // Removes all milestones from the internal list and from the database
  void clearDatabase() {
    if (!idbAvailable) { milestones.clear(); msg =''; return; }
    
    Transaction t = indexedDB.transaction(storeName, 'readwrite');
    t.objectStore(storeName).clear()
    .then((request) {
      print('database cleared');
      milestones.clear();
      msg = '';
    });
  }
  
  // + button click handler.
  // Does some boundary checking, then calls _addMilestone() to
  // Really add a milestone to the internal list and to the database.
  void addMilestone() {
    print('in addMilestone');
        
    // Concatenate date and time entered by user.
    String str = newMilestoneDate + ' ' + newMilestoneTime;
    
    // Make sure milestone name is unique
    for (int i = 0; i < milestones.length; i++) {
      if (milestones[i].name == newMilestoneName) {
        msg = '$newMilestoneName is already in database';
        return;
      }
    }
    
    // Make sure milestone is in the future, and not in the past.
    var now = new DateTime.now();
    var milestoneTime = DateTime.parse(str);
    if (milestoneTime.isAfter(now)) { // If milestone is in the future, add milestone.
      _addMilestone(newMilestoneName, str);
      print('adding $newMilestoneName $str');
      msg = '';
    } else {
      msg = 'Milestone must be later than now.';
    }
  }
  
  // Called from initializeFromDB and from + button click handler.
  void _addMilestone(String name, String dateAndTime) {
    print('in _addMilestone');
    print(dateAndTime);
    
    if (!idbAvailable) {
      milestones.add(new Milestone(name, dateAndTime, name));
      startMilestoneTimer();
      return;
    }
    
    Transaction t = indexedDB.transaction(storeName, 'readwrite');
    t.objectStore(storeName).put(dateAndTime, name) /* it's value first, then key. who's idea was that? */
    .then((IDBRequest) {
      // Add a new milestone
      milestones.add(new Milestone(name, dateAndTime, name));
      startMilestoneTimer();
    });
  }
  
  // - button click handler.
  // Removes the associated item from the internal list and from the database.
  void removeMilestone(int index) {
    print('in removeMilestone');
    print(index);

    if (!idbAvailable) {
      milestones.removeAt(index);
      msg = '';
      
      // Turn off the timer if no more milestones to count down.
      if (milestones.length == 0) {
        timer.cancel();
        timer = null;
      }
    }
    
    Transaction t = indexedDB.transaction(storeName, 'readwrite');
    t.objectStore(storeName).delete(milestones[index].name)
    .then((IDBRequest) {
      // Remove the data.
      milestones.removeAt(index);
      msg = '';
      
      // Turn off the timer if no more milestones to count down.
      if (milestones.length == 0) {
        timer.cancel();
        timer = null;
      }
    });
  }

  /*
   * Timer stuff.
   */
  // Starts the time if it's not on (timer is null).
  // Turned on when adding milestones.
  // Turned off when removing milestones.
  void startMilestoneTimer() {
    if (timer == null) {
      // The timer goes off every second
      var oneSecond = new Duration(seconds:1);
      timer = new Timer.periodic(oneSecond, updateDisplays);
    }
  }
  
  // Update the display for each milestone.
  void updateDisplays(Timer _) {
    // What time is it now?
    var now = new DateTime.now();

    // For each milestone, figure out how many seconds between now and then...
    for (int i = 0; i < milestones.length; i++) {

      // If milestone hasn't already passed...
      if (!milestones[i].display.startsWith('Huzzah')) {
        // What time is the milestone?
        var milestoneTime = DateTime.parse(milestones[i].dateAndTime);
        
        // What is the difference between now and milestone in seconds?
        int secs = milestoneTime.difference(now).inSeconds;
       
        if (secs <= 0) {
          // Milestone has JUST occurred.
          timeRemaining = 'Huzzah for ${milestones[i].name}!';
          milestones[i].display = timeRemaining;
        } else {
          // Still counting down...display it.
          // These are observable strings, so web page gets automatically updated.
          timeRemaining = formatDisplayString(secs);
          milestones[i].display = timeRemaining + ' until ${milestones[i].name}';
        } // end if-else
      } // end if
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
