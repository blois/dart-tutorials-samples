library milestone;

import 'package:web_ui/web_ui.dart';
import 'dart:async';
import 'dart:html';
import 'dart:indexed_db';

// For development.
bool verbose = true;
void log(msg) {
  if (verbose) print('$msg');
}

// A class to hold the milestone info.
@observable 
class Milestone {
  final String name;
  final DateTime dateAndTime;
  String display;
  var dbKey;
  bool elapsed = false;
  
  Milestone(this.name, this.dateAndTime, this.display);
  
  
  String toString() => '$name $dateAndTime $display';
  
  // Constructor which creates a milestone from the value stored
  // in the database.
  Milestone.fromRaw(key, Map value):
    dbKey = key,
    name = value['name'],
    dateAndTime = DateTime.parse(value['dateAndTime']) {
    
    updateDisplay(new DateTime.now());
  }
  
  /// Serialize this to an object we can insert into the database.
  Map toRaw() {
    return {
      'name': name,
      'dateAndTime': dateAndTime.toString(),
    };
  }
  
  void updateDisplay(DateTime now) {
    if (elapsed) {
      return;
    }
    
    if (now.isAfter(dateAndTime)) {
      // Milestone has JUST occurred.
      display = 'Huzzah for $name!';
    } else {          // Still counting down...display it.
      var remaining = dateAndTime.difference(now);
      
      // These are observable strings, so web page gets automatically updated.
      display = _formatDisplayString(remaining);
    }
  }
    
  String _formatDisplayString(Duration remaining) { 
    // Calculate days, hours, and minutes remaining.
    int d = remaining.inDays;
    int h = remaining.inHours.remainder(Duration.HOURS_PER_DAY);
    int m = remaining.inMinutes.remainder(Duration.MINUTES_PER_HOUR);
    int s = remaining.inSeconds.remainder(Duration.SECONDS_PER_MINUTE);
    
    // Format individual pieces of the display string.
    String days = (d == 0) ? '' : '$d Days';
    String hours = (h == 0) ? '' : '$h Hours';
    String minutes = (m == 0) ? '' : '$m Minutes';
    String seconds = '$s Seconds';
    
    return '$days $hours $minutes $seconds until $name';
  }
}

/// Manages all of the milestones in the database.
class MilestoneStore {
  static const String MILESTONE_STORE = 'milestoneStore';
  static const String NAME_INDEX = 'name_index';
  
  final List<Milestone> milestones = toObservable(new List());
  
  Database _db;
  
  Future open() {
    return window.indexedDB.open('milestoneDB',
        version: 1,
        onUpgradeNeeded: _initializeDatabase)
        .then(_initializeFromDB);
  }
  
  /// Initializes the object store if it is brand new, or upgrades it if it
  /// is an older version. 
  void _initializeDatabase(VersionChangeEvent e) {
    Database db = (e.target as Request).result;
    
    var objectStore = db.createObjectStore(MILESTONE_STORE,
        autoIncrement: true);
    // Create an index to search by name, don't want conflicting events
    // so set unique.
    var index = objectStore.createIndex(NAME_INDEX, 'name',
        unique: true);
  }
  
  /// Loads all of the existing objects from the database.
  ///
  /// The future completes when loading is finished.
  Future _initializeFromDB(Database db) {
    log('in _initializeFromDB MS');
    
    _db = db;
    
    var trans = db.transaction(MILESTONE_STORE, 'readonly');
    var store = trans.objectStore(MILESTONE_STORE);
    
    // Get everything in the store.
    var cursors = store.openCursor(autoAdvance: true).asBroadcastStream();
    cursors.listen((cursor) {
      // Add milestone to the internal list.
      var milestone = new Milestone.fromRaw(cursor.key, cursor.value);
      milestones.add(milestone);
    });
    
    return cursors.length.then((length) {
      // Start the timer when all milestones have been read.
      //startMilestoneTimer();
      print('Read $length records.');
    });
  }
  
  /// Add a new milestone to the milestones in the Database.
  /// 
  /// This returns a Future with the new milestone when the milestone
  /// has been added.
  Future<Milestone> add(String milestoneName, DateTime dateAndTime) {
    var milestone = new Milestone(milestoneName, dateAndTime, milestoneName);
    // Add to database.
    var transaction = _db.transaction(MILESTONE_STORE, 'readwrite');
    transaction.objectStore(MILESTONE_STORE).add(milestone.toRaw()).then((addedKey) {
      // NOTE! The key cannot be used until the transaction completes.
      milestone.dbKey = addedKey;
    });
    
    // Note that the milestone cannot be queried until the transaction
    // has completed!
    return transaction.completed.then((_) {
      // Once the transaction completes, add it to our list of available items.
      milestones.add(milestone);
      
      // Return the milestone so this becomes the result of the future.
      return milestone;
    });
  }
  
  /// Removes a milestone from the list of milestones.
  /// 
  /// This returns a Future which completes when the milestone has been 
  /// removed.
  Future remove(Milestone milestone) {
    log('in removeMilestone: ${milestone.name}');
    
    // Remove from database.
    var transaction = _db.transaction(MILESTONE_STORE, 'readwrite');
    transaction.objectStore(MILESTONE_STORE).delete(milestone.dbKey);
    
    return transaction.completed.then((_) {
      // Null out the key to indicate that the milestone is dead.
      milestone.dbKey = null;
      // Remove from internal list.
      milestones.remove(milestone);
    });
  }
  
  Future clear() {
    log('in clearDatabase');
    
    // Clear database.
    var transaction = _db.transaction(MILESTONE_STORE, 'readwrite');
    transaction.objectStore(MILESTONE_STORE).clear();
    
    return transaction.completed.then((_) {
      // Clear internal list.
      print('database cleared');
      milestones.clear();
    });
  }
  
  Future<int> get count {
    // Count records in database.
    var transaction = _db.transaction(MILESTONE_STORE, 'readonly');
    return transaction.objectStore(MILESTONE_STORE).count();
  }
}