import 'dart:convert';
import 'dart:developer';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:nostrmo/client/nip51/bookmarks.dart';
import 'package:nostrmo/component/enum_selector_component.dart';
import 'package:nostrmo/component/like_text_select_bottom_sheet.dart';
import 'package:nostrmo/consts/base.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../client/event.dart';
import '../../client/event_relation.dart';
import '../../client/nip19/nip19.dart';
import '../../client/zap/zap_action.dart';
import '../../consts/base_consts.dart';
import '../../consts/router_path.dart';
import '../../data/event_reactions.dart';
import '../../generated/l10n.dart';
import '../../main.dart';
import '../../provider/event_reactions_provider.dart';
import '../../router/edit/editor_router.dart';
import '../../util/number_format_util.dart';
import '../../util/router_util.dart';
import '../../util/store_util.dart';
import '../../util/string_util.dart';
import '../editor/cust_embed_types.dart';
import '../event_delete_callback.dart';
import '../event_reply_callback.dart';
import '../zap/zap_bottom_sheet_component.dart';

class EventReactionsComponent extends StatefulWidget {
  ScreenshotController screenshotController;

  Event event;

  EventRelation eventRelation;

  bool showDetailBtn;

  EventReactionsComponent({
    required this.screenshotController,
    required this.event,
    required this.eventRelation,
    this.showDetailBtn = true,
  });

  @override
  State<StatefulWidget> createState() {
    return _EventReactionsComponent();
  }
}

class _EventReactionsComponent extends State<EventReactionsComponent> {
  List<Event>? myLikeEvents;

  @override
  Widget build(BuildContext context) {
    var s = S.of(context);
    var themeData = Theme.of(context);
    var hintColor = themeData.hintColor;
    var fontSize = themeData.textTheme.bodySmall!.fontSize!;
    var mainColor = themeData.primaryColor;
    var mediumFontSize = themeData.textTheme.bodyMedium!.fontSize;
    var popFontStyle = TextStyle(
      fontSize: mediumFontSize,
    );

    return Selector<EventReactionsProvider, EventReactions?>(
      builder: (context, eventReactions, child) {
        int replyNum = 0;
        int repostNum = 0;
        int likeNum = 0;
        int zapNum = 0;
        Color likeColor = hintColor;

        if (eventReactions != null) {
          replyNum = eventReactions.replies.length;
          repostNum = eventReactions.repostNum;
          likeNum = eventReactions.likeNum;
          zapNum = eventReactions.zapNum;

          myLikeEvents = eventReactions.myLikeEvents;
        }
        if (myLikeEvents != null && myLikeEvents!.isNotEmpty) {
          likeColor = mainColor;
        }

        String? iconText;
        Widget? showMoreWidget;
        IconData likeIconData = Icons.add_reaction_outlined;
        if (eventReactions != null) {
          var mapLength = eventReactions.likeNumMap.length;
          if (mapLength == 1) {
            iconText = eventReactions.likeNumMap.keys.first;
          } else if (mapLength > 1) {
            int maxNum = 0;
            for (var entry in eventReactions.likeNumMap.entries) {
              if (entry.value > maxNum) {
                iconText = entry.key;
                maxNum = entry.value;
              }
            }

            var iconData = Icons.keyboard_double_arrow_down;
            if (showMoreLike) {
              iconData = Icons.keyboard_double_arrow_up;
            }

            showMoreWidget = GestureDetector(
              onTap: showMoreLikeTap,
              child: Icon(iconData, color: likeColor),
            );
          }
        }
        Widget likeWidget = EventReactionNumComponent(
          num: likeNum,
          iconText: iconText,
          iconData: likeIconData,
          onTap: onLikeTap,
          color: likeColor,
          fontSize: fontSize,
          showMoreWidget: showMoreWidget,
        );

        Widget moreBtnWidget = Container(
          alignment: Alignment.center,
          child: PopupMenuButton<String>(
            tooltip: s.More,
            itemBuilder: (context) {
              var bookmarkItem =
                  BookmarkItem.getFromEventReactions(widget.eventRelation);

              List<PopupMenuEntry<String>> list = [
                PopupMenuItem(
                  value: "copyEvent",
                  child: Text(s.Copy_Note_Json, style: popFontStyle),
                ),
                PopupMenuItem(
                  value: "copyPubkey",
                  child: Text(s.Copy_Note_Pubkey, style: popFontStyle),
                ),
                PopupMenuItem(
                  value: "copyId",
                  child: Text(s.Copy_Note_Id, style: popFontStyle),
                ),
                PopupMenuDivider(),
              ];

              if (widget.showDetailBtn) {
                list.add(PopupMenuItem(
                  value: "detail",
                  child: Text(s.Detail, style: popFontStyle),
                ));
              }

              list.add(PopupMenuItem(
                value: "share",
                child: Text(s.Share, style: popFontStyle),
              ));
              list.add(PopupMenuDivider());
              if (listProvider.checkPrivateBookmark(bookmarkItem)) {
                list.add(PopupMenuItem(
                  value: "removeFromPrivateBookmark",
                  child:
                      Text(s.Remove_from_private_bookmark, style: popFontStyle),
                ));
              } else {
                list.add(PopupMenuItem(
                  value: "addToPrivateBookmark",
                  child: Text(s.Add_to_private_bookmark, style: popFontStyle),
                ));
              }
              if (listProvider.checkPublicBookmark(bookmarkItem)) {
                list.add(PopupMenuItem(
                  value: "removeFromPublicBookmark",
                  child:
                      Text(s.Remove_from_public_bookmark, style: popFontStyle),
                ));
              } else {
                list.add(PopupMenuItem(
                  value: "addToPublicBookmark",
                  child: Text(s.Add_to_public_bookmark, style: popFontStyle),
                ));
              }
              list.add(PopupMenuDivider());
              list.add(PopupMenuItem(
                value: "source",
                child: Text(s.Source, style: popFontStyle),
              ));
              list.add(PopupMenuItem(
                value: "broadcase",
                child: Text(s.Broadcast, style: popFontStyle),
              ));
              list.add(PopupMenuItem(
                value: "block",
                child: Text(s.Block, style: popFontStyle),
              ));

              if (widget.event.pubkey == nostr!.publicKey) {
                list.add(PopupMenuDivider());
                list.add(PopupMenuItem(
                  value: "delete",
                  child: Text(
                    s.Delete,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: mediumFontSize,
                    ),
                  ),
                ));
              }

              return list;
            },
            onSelected: onPopupSelected,
            child: Container(
              height: double.infinity,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(
                left: Base.BASE_PADDING_HALF,
                right: Base.BASE_PADDING_HALF,
              ),
              child: Icon(
                Icons.more_vert,
                size: 16,
                color: hintColor,
              ),
            ),
          ),
        );

        var topReactionsWidget = Row(
          children: [
            Expanded(
                child: Container(
              alignment: Alignment.centerLeft,
              child: EventReactionNumComponent(
                num: replyNum,
                iconData: Icons.comment,
                onTap: onCommmentTap,
                color: hintColor,
                fontSize: fontSize,
              ),
            )),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                child: PopupMenuButton<String>(
                  tooltip: s.Boost,
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem(
                        value: "boost",
                        child: Text(s.Boost),
                      ),
                      PopupMenuItem(
                        value: "quote",
                        child: Text(s.Quote),
                      ),
                    ];
                  },
                  onSelected: onRepostTap,
                  child: EventReactionNumComponent(
                    num: repostNum,
                    iconData: Icons.repeat,
                    color: hintColor,
                    fontSize: fontSize,
                  ),
                ),
              ),
            ),
            Expanded(
                child: Container(
              alignment: Alignment.center,
              child: likeWidget,
            )),
            Expanded(
                child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: openZapDialog,
              child: Container(
                height: double.infinity,
                child: EventReactionNumComponent(
                  num: zapNum,
                  iconData: Icons.bolt,
                  onTap: null,
                  color: hintColor,
                  fontSize: fontSize,
                ),
              ),
            )),
            moreBtnWidget,
          ],
        );

        List<Widget> mainList = [
          Container(
            height: 34,
            child: topReactionsWidget,
          )
        ];

        if (showMoreLike &&
            eventReactions != null &&
            eventReactions.likeNumMap.length > 1) {
          Map<String, int> myLikeMap = {};
          if (eventReactions.myLikeEvents != null) {
            for (var event in eventReactions.myLikeEvents!) {
              var likeText = EventReactions.getLikeText(event);
              myLikeMap[likeText] = 1;
            }
          }
          List<Widget> ers = [];
          for (var entry in eventReactions.likeNumMap.entries) {
            var likeText = entry.key;
            var num = entry.value;

            Color color = hintColor;
            if (myLikeMap[likeText] != null) {
              color = mainColor;
            }

            ers.add(Container(
              margin: const EdgeInsets.only(right: Base.BASE_PADDING_HALF),
              child: EventReactionEmojiNumComponent(
                iconData: Icons.favorite,
                iconText: likeText,
                num: num,
                color: color,
                fontSize: fontSize,
              ),
            ));
          }

          mainList.add(Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(
              left: Base.BASE_PADDING,
              right: Base.BASE_PADDING,
              bottom: Base.BASE_PADDING_HALF,
            ),
            width: double.maxFinite,
            child: Wrap(
              runSpacing: Base.BASE_PADDING_HALF,
              spacing: Base.BASE_PADDING_HALF,
              alignment: WrapAlignment.center,
              children: ers,
            ),
          ));
        }

        return Container(
          padding: const EdgeInsets.only(
            bottom: Base.BASE_PADDING_HALF,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: mainList,
          ),
        );
      },
      selector: (context, _provider) {
        return _provider.get(widget.event.id);
      },
      shouldRebuild: (previous, next) {
        if ((previous == null && next != null) ||
            (previous != null &&
                next != null &&
                (previous.replies.length != next.replies.length ||
                    previous.repostNum != next.repostNum ||
                    previous.likeNum != next.likeNum ||
                    previous.zapNum != next.zapNum))) {
          return true;
        }

        return false;
      },
    );
  }

  void onPopupSelected(String value) {
    if (value == "copyEvent") {
      var text = jsonEncode(widget.event.toJson());
      _doCopy(text);
    } else if (value == "copyPubkey") {
      var text = Nip19.encodePubKey(widget.event.pubkey);
      _doCopy(text);
    } else if (value == "copyId") {
      var text = Nip19.encodeNoteId(widget.event.id);
      _doCopy(text);
    } else if (value == "detail") {
      RouterUtil.router(context, RouterPath.EVENT_DETAIL, widget.event);
    } else if (value == "share") {
      onShareTap();
    } else if (value == "addToPrivateBookmark") {
      var item = BookmarkItem.getFromEventReactions(widget.eventRelation);
      listProvider.addPrivateBookmark(item);
    } else if (value == "addToPublicBookmark") {
      var item = BookmarkItem.getFromEventReactions(widget.eventRelation);
      listProvider.addPublicBookmark(item);
    } else if (value == "removeFromPrivateBookmark") {
      var item = BookmarkItem.getFromEventReactions(widget.eventRelation);
      listProvider.removePrivateBookmark(item.value);
    } else if (value == "removeFromPublicBookmark") {
      var item = BookmarkItem.getFromEventReactions(widget.eventRelation);
      listProvider.removePublicBookmark(item.value);
    } else if (value == "broadcase") {
      nostr!.broadcase(widget.event);
    } else if (value == "source") {
      List<EnumObj> list = [];
      for (var source in widget.event.sources) {
        list.add(EnumObj(source, source));
      }
      EnumSelectorComponent.show(context, list);
    } else if (value == "block") {
      filterProvider.addBlock(widget.event.pubkey);
    } else if (value == "delete") {
      nostr!.deleteEvent(widget.event.id);
      followEventProvider.deleteEvent(widget.event.id);
      mentionMeProvider.deleteEvent(widget.event.id);
      var deleteCallback = EventDeleteCallback.of(context);
      if (deleteCallback != null) {
        deleteCallback.onDelete(widget.event);
      }
      // BotToast.showText(text: "Delete success!");
    }
  }

  void _doCopy(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      BotToast.showText(text: S.of(context).Copy_success);
    });
  }

  @override
  void dispose() {
    super.dispose();
    var id = widget.event.id;
    eventReactionsProvider.removePendding(id);
  }

  Future<void> onCommmentTap() async {
    var er = widget.eventRelation;
    List<dynamic> tags = [];
    List<dynamic> tagsAddedWhenSend = [];
    String relayAddr = "";
    if (widget.event.sources.isNotEmpty) {
      relayAddr = widget.event.sources[0];
    }
    String directMarked = "reply";
    if (StringUtil.isBlank(er.rootId)) {
      directMarked = "root";
    }
    tagsAddedWhenSend.add(["e", widget.event.id, relayAddr, directMarked]);

    List<dynamic> tagPs = [];
    tagPs.add(["p", widget.event.pubkey]);
    if (er.tagPList.isNotEmpty) {
      for (var p in er.tagPList) {
        tagPs.add(["p", p]);
      }
    }
    if (StringUtil.isNotBlank(er.rootId)) {
      String relayAddr = "";
      if (StringUtil.isNotBlank(er.rootRelayAddr)) {
        relayAddr = er.rootRelayAddr!;
      }
      if (StringUtil.isBlank(relayAddr)) {
        var rootEvent = singleEventProvider.getEvent(er.rootId!);
        if (rootEvent != null && rootEvent.sources.isNotEmpty) {
          relayAddr = rootEvent.sources[0];
        }
      }
      tags.add(["e", er.rootId, relayAddr, "root"]);
    }

    // TODO reply maybe change the placeholder in editor router.
    var event = await EditorRouter.open(context,
        tags: tags, tagsAddedWhenSend: tagsAddedWhenSend, tagPs: tagPs);
    if (event != null) {
      eventReactionsProvider.addEventAndHandle(event);
      var callback = EventReplyCallback.of(context);
      if (callback != null) {
        callback.onReply(event);
      }
    }
  }

  Future<void> onRepostTap(String value) async {
    if (value == "boost") {
      String? relayAddr;
      if (widget.event.sources.isNotEmpty) {
        relayAddr = widget.event.sources[0];
      }
      var content = jsonEncode(widget.event.toJson());
      nostr!
          .sendRepost(widget.event.id, relayAddr: relayAddr, content: content);
      eventReactionsProvider.addRepost(widget.event.id);

      if (settingProvider.broadcaseWhenBoost == OpenStatus.OPEN) {
        nostr!.broadcase(widget.event);
      }
    } else if (value == "quote") {
      var event = await EditorRouter.open(context, initEmbeds: [
        quill.CustomBlockEmbed(CustEmbedTypes.mention_event, widget.event.id)
      ]);
    }
  }

  Future<void> onLikeTap() async {
    if (myLikeEvents == null || myLikeEvents!.isEmpty) {
      // like
      // get emoji text
      var emojiText = await selectLikeEmojiText();
      if (StringUtil.isBlank(emojiText)) {
        return;
      }

      var likeEvent = nostr!.sendLike(widget.event.id, content: emojiText);
      if (likeEvent != null) {
        eventReactionsProvider.addLike(widget.event.id, likeEvent);
      }
    } else {
      // delete like
      for (var event in myLikeEvents!) {
        nostr!.deleteEvent(event.id);
      }
      eventReactionsProvider.deleteLike(widget.event.id);
    }
  }

  void onShareTap() {
    widget.screenshotController.capture().then((Uint8List? imageData) async {
      if (imageData != null) {
        if (imageData != null) {
          var tempFile = await StoreUtil.saveBS2TempFile(
            "png",
            imageData,
          );
          Share.shareXFiles([XFile(tempFile)]);
        }
      }
    }).catchError((onError) {
      print(onError);
    });
  }

  bool showMoreLike = false;

  void showMoreLikeTap() {
    setState(() {
      showMoreLike = !showMoreLike;
    });
  }

  Future<String?> selectLikeEmojiText() async {
    var text = await showModalBottomSheet(
      isScrollControlled: false,
      context: context,
      builder: (context) {
        return LikeTextSelectBottomSheet();
      },
    );

    return text;
  }

  void openZapDialog() {
    List<EventZapInfo> list = [];
    var zapInfos = widget.eventRelation.zapInfos;
    if (zapInfos.isEmpty) {
      String relayAddr = "";
      var relayListMetadata =
          metadataProvider.getRelayListMetadata(widget.event.pubkey);
      if (relayListMetadata != null &&
          relayListMetadata.writeAbleRelays.isNotEmpty) {
        relayAddr = relayListMetadata.writeAbleRelays.first;
      }
      list.add(EventZapInfo(widget.event.pubkey, relayAddr, 1));
    } else {
      list.addAll(zapInfos);
    }

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext _context) {
        return ZapBottomSheetComponent(
          context,
          list,
          eventId: widget.event.id,
        );
      },
    );
  }
}

class EventReactionNumComponent extends StatelessWidget {
  String? iconText;

  IconData iconData;

  int num;

  GestureTapCallback? onTap;

  GestureLongPressCallback? onLongPress;

  Color color;

  double fontSize;

  Widget? showMoreWidget;

  EventReactionNumComponent({
    this.iconText,
    required this.iconData,
    required this.num,
    this.onTap,
    this.onLongPress,
    required this.color,
    required this.fontSize,
    this.showMoreWidget,
  });

  @override
  Widget build(BuildContext context) {
    Widget? main;
    var iconWidget = Icon(
      iconData,
      size: 14,
      color: color,
    );

    List<Widget> list = [];
    if (StringUtil.isNotBlank(iconText)) {
      list.add(Text(iconText!));
    } else {
      list.add(iconWidget);
    }

    if (num != 0) {
      String numStr = NumberFormatUtil.format(num);

      list.add(Container(
        margin: const EdgeInsets.only(left: 4),
        child: Text(
          numStr,
          style: TextStyle(color: color, fontSize: fontSize),
        ),
      ));
      if (showMoreWidget != null) {
        list.add(showMoreWidget!);
      }
    }

    main = Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: list,
    );
    main = Container(
      height: double.infinity,
      child: main,
    );

    if (onTap != null || onLongPress != null) {
      return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.translucent,
        child: main,
      );
    } else {
      return main;
    }
  }
}

class EventReactionEmojiNumComponent extends StatelessWidget {
  String? iconText;

  IconData iconData;

  int num;

  Color color;

  double fontSize;

  EventReactionEmojiNumComponent({
    this.iconText,
    required this.iconData,
    required this.num,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(
      iconData,
      size: 14,
      color: color,
    );

    List<Widget> list = [];
    if (StringUtil.isNotBlank(iconText)) {
      list.add(Text(iconText!));
    } else {
      list.add(iconWidget);
    }

    if (num != 0) {
      String numStr = NumberFormatUtil.format(num);

      list.add(Container(
        margin: const EdgeInsets.only(left: 4),
        child: Text(
          numStr,
          style: TextStyle(color: color, fontSize: fontSize),
        ),
      ));
    }

    return Container(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: list,
      ),
    );
  }
}
