import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';

import '../../client/event_kind.dart' as kind;
import '../client/event.dart';
import '../client/nip02/contact.dart';
import '../client/nip02/cust_contact_list.dart';
import '../client/filter.dart';
import '../client/nostr.dart';
import '../data/event_mem_box.dart';
import '../main.dart';
import '../util/find_event_interface.dart';
import '../util/peddingevents_later_function.dart';
import '../util/string_util.dart';

class FollowEventProvider extends ChangeNotifier
    with PenddingEventsLaterFunction
    implements FindEventInterface {
  int queryTimeInterval = 60 * 2;

  late int _initTime;

  late EventMemBox eventBox;

  late EventMemBox postsBox;

  FollowEventProvider() {
    _initTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    eventBox = EventMemBox(sortAfterAdd: false); // sortAfterAdd by call
    postsBox = EventMemBox(sortAfterAdd: false);
  }

  @override
  List<Event> findEvent(String str, {int? limit = 5}) {
    return eventBox.findEvent(str, limit: limit);
  }

  List<Event> eventsByPubkey(String pubkey) {
    return eventBox.listByPubkey(pubkey);
  }

  void refresh() {
    _initTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    eventBox.clear();
    postsBox.clear();
    doQuery();

    followNewEventProvider.clear();
  }

  int lastTime() {
    return _initTime;
  }

  List<String> _subscribeIds = [];

  void deleteEvent(String id) {
    postsBox.delete(id);
    var result = eventBox.delete(id);
    if (result) {
      notifyListeners();
    }
  }

  List<int> queryEventKinds() {
    return [
      kind.EventKind.TEXT_NOTE,
      kind.EventKind.REPOST,
      kind.EventKind.LONG_FORM,
      kind.EventKind.FILE_HEADER,
      kind.EventKind.POLL,
    ];
  }

  void doQuery({Nostr? targetNostr, bool initQuery = false, int? until}) {
    var filter = Filter(
      kinds: queryEventKinds(),
      until: until ?? _initTime,
      limit: 100,
    );
    targetNostr ??= nostr!;

    doUnscribe(targetNostr);

    List<String> subscribeIds = [];
    Iterable<Contact> contactList = contactListProvider.list();
    List<String> ids = [];
    // timeline pull my events too.
    ids.add(targetNostr.publicKey);
    for (Contact contact in contactList) {
      ids.add(contact.publicKey);
      if (ids.length > 100) {
        filter.authors = ids;
        var subscribeId =
            _doQueryFunc(targetNostr, filter, initQuery: initQuery);
        subscribeIds.add(subscribeId);
        ids = [];
      }
    }
    if (ids.isNotEmpty) {
      filter.authors = ids;
      var subscribeId = _doQueryFunc(targetNostr, filter, initQuery: initQuery);
      subscribeIds.add(subscribeId);
    }

    if (!initQuery) {
      _subscribeIds = subscribeIds;
    }
  }

  void doUnscribe(Nostr targetNostr) {
    if (_subscribeIds.isNotEmpty) {
      for (var subscribeId in _subscribeIds) {
        try {
          targetNostr.unsubscribe(subscribeId);
        } catch (e) {}
      }
      _subscribeIds.clear();
    }
  }

  String _doQueryFunc(Nostr targetNostr, Filter filter,
      {bool initQuery = false}) {
    var subscribeId = StringUtil.rndNameStr(12);
    if (initQuery) {
      // targetNostr.pool.subscribe([filter.toJson()], onEvent, subscribeId);
      targetNostr.addInitQuery([filter.toJson()], onEvent, id: subscribeId);
    } else {
      targetNostr.query([filter.toJson()], onEvent, id: subscribeId);
    }
    return subscribeId;
  }

  // check if is posts (no tag e and not Mentions, TODO handle NIP27)
  static bool eventIsPost(Event event) {
    bool isPosts = true;
    var tagLength = event.tags.length;
    for (var i = 0; i < tagLength; i++) {
      var tag = event.tags[i];
      if (tag.length > 0 && tag[0] == "e") {
        if (event.content.contains("[$i]")) {
          continue;
        }

        isPosts = false;
        break;
      }
    }

    return isPosts;
  }

  void mergeNewEvent() {
    var allEvents = followNewEventProvider.eventMemBox.all();
    var postEvnets = followNewEventProvider.eventPostMemBox.all();

    eventBox.addList(allEvents);
    postsBox.addList(postEvnets);

    // sort
    eventBox.sort();
    postsBox.sort();

    followNewEventProvider.clear();

    // update ui
    notifyListeners();
  }

  void onEvent(Event event) {
    if (eventBox.isEmpty()) {
      laterTimeMS = 200;
    } else {
      laterTimeMS = 500;
    }
    later(event, (list) {
      bool added = false;
      for (var e in list) {
        var result = eventBox.add(e);
        if (result) {
          // add success
          added = true;

          // check if is posts (no tag e)
          bool isPosts = eventIsPost(e);
          if (isPosts) {
            postsBox.add(e);
          }
        }
      }

      if (added) {
        // sort
        eventBox.sort();
        postsBox.sort();

        // update ui
        notifyListeners();
      }
    }, null);
  }

  void clear() {
    eventBox.clear();
    postsBox.clear();

    doUnscribe(nostr!);

    notifyListeners();
  }

  void metadataUpdatedCallback(CustContactList? _contactList) {
    if (firstLogin ||
        (eventBox.isEmpty() &&
            _contactList != null &&
            !_contactList.isEmpty())) {
      doQuery();
    }

    if (firstLogin && _contactList != null && _contactList.list().length > 10) {
      firstLogin = false;
    }
  }
}
