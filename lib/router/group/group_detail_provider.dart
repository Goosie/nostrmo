import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nostrmo/client/nip29/group_identifier.dart';

import '../../client/event.dart';
import '../../client/event_kind.dart';
import '../../client/filter.dart';
import '../../data/event_mem_box.dart';
import '../../main.dart';
import '../../util/peddingevents_later_function.dart';

class GroupDetailProvider extends ChangeNotifier
    with PenddingEventsLaterFunction {
  late int _initTime;

  GroupIdentifier? _groupIdentifier;

  EventMemBox newNotesBox = EventMemBox(sortAfterAdd: false);

  EventMemBox notesBox = EventMemBox(sortAfterAdd: false);

  EventMemBox chatsBox = EventMemBox(sortAfterAdd: false);

  GroupDetailProvider() {
    _initTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  void clear() {
    _groupIdentifier = null;
    clearData();
  }

  void clearData() {
    newNotesBox.clear();
    notesBox.clear();
    chatsBox.clear();
  }

  Timer? timer;

  void startQueryTask() {
    clearTimer();

    timer = Timer.periodic(const Duration(seconds: 20), (t) {
      try {
        _queryNewEvent();
      } catch (e) {}
    });
  }

  @override
  void dispose() {
    super.dispose;
    clear();

    clearTimer();
  }

  void clearTimer() {
    if (timer != null) {
      timer!.cancel();
      timer = null;
    }
  }

  void _queryNewEvent() {
    if (_groupIdentifier != null) {
      var relays = [_groupIdentifier!.host];
      var filter = Filter(
        since: _initTime,
        kinds: supportEventKinds,
      );
      var jsonMap = filter.toJson();
      jsonMap["#h"] = [_groupIdentifier!.groupId];
      nostr!.query(
        [jsonMap],
        _onNewEvent,
        tempRelays: relays,
        onlyTempRelays: true,
        queryLocal: false,
        sendAfterAuth: true,
      );
    }
  }

  void _onNewEvent(Event e) {
    if (e.kind == EventKind.GROUP_NOTE ||
        e.kind == EventKind.GROUP_NOTE_REPLY) {
      if (newNotesBox.add(e)) {
        if (e.createdAt > _initTime) {
          _initTime = e.createdAt;
        }
        notifyListeners();
      }
    } else if (e.kind == EventKind.GROUP_CHAT_MESSAGE ||
        e.kind == EventKind.GROUP_CHAT_REPLY) {
      if (chatsBox.add(e)) {
        chatsBox.sort();
        notifyListeners();
      }
    }
  }

  void mergeNewEvent() {
    var isNotEmpty = newNotesBox.all().isNotEmpty;
    notesBox.addBox(newNotesBox);
    if (isNotEmpty) {
      newNotesBox.clear();
      notesBox.sort();
      notifyListeners();
    }
  }

  static List<int> supportEventKinds = [
    EventKind.GROUP_NOTE,
    EventKind.GROUP_NOTE_REPLY,
    EventKind.GROUP_CHAT_MESSAGE,
    EventKind.GROUP_CHAT_REPLY,
  ];

  void doQuery(int? until) {
    if (_groupIdentifier != null) {
      var relays = [_groupIdentifier!.host];
      var filter = Filter(
        until: until ?? _initTime,
        kinds: supportEventKinds,
      );
      var jsonMap = filter.toJson();
      jsonMap["#h"] = [_groupIdentifier!.groupId];
      nostr!.query(
        [jsonMap],
        onEvent,
        tempRelays: relays,
        onlyTempRelays: true,
        queryLocal: false,
        sendAfterAuth: true,
      );
    }
  }

  void onEvent(Event event) {
    later(event, (list) {
      bool noteAdded = false;
      bool chatAdded = false;

      for (var e in list) {
        if (e.kind == EventKind.GROUP_NOTE ||
            e.kind == EventKind.GROUP_NOTE_REPLY) {
          if (notesBox.add(e)) {
            noteAdded = true;
          }
        } else if (e.kind == EventKind.GROUP_CHAT_MESSAGE ||
            e.kind == EventKind.GROUP_CHAT_REPLY) {
          if (chatsBox.add(e)) {
            chatAdded = true;
          }
        }
      }

      if (noteAdded) {
        notesBox.sort();
      }
      if (chatAdded) {
        chatsBox.sort();
      }

      if (noteAdded || chatAdded) {
        // update ui
        notifyListeners();
      }
    }, null);
  }

  void updateGroupIdentifier(GroupIdentifier groupIdentifier) {
    if (_groupIdentifier == null ||
        _groupIdentifier.toString() != groupIdentifier.toString()) {
      // clear and need to query data
      clearData();
      _groupIdentifier = groupIdentifier;
      doQuery(null);
    } else {
      _groupIdentifier = groupIdentifier;
    }
  }

  refresh() {
    clearData();
    _initTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    doQuery(null);
  }
}
