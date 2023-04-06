import 'package:flutter/material.dart';
import 'package:nostrmo/component/user/metadata_top_component.dart';
import 'package:nostrmo/consts/base.dart';
import 'package:nostrmo/consts/router_path.dart';
import 'package:nostrmo/data/dm_session_info_db.dart';
import 'package:nostrmo/data/event_db.dart';
import 'package:nostrmo/data/metadata_db.dart';
import 'package:nostrmo/router/user/user_statistics_component.dart';
import 'package:nostrmo/util/router_util.dart';
import 'package:provider/provider.dart';

import '../../component/user/metadata_component.dart';
import '../../data/metadata.dart';
import '../../main.dart';
import '../../provider/metadata_provider.dart';

class IndexDrawerContnetComponnent extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _IndexDrawerContnetComponnent();
  }
}

class _IndexDrawerContnetComponnent
    extends State<IndexDrawerContnetComponnent> {
  double profileEditBtnWidth = 40;

  @override
  Widget build(BuildContext context) {
    var pubkey = nostr!.publicKey;
    var paddingTop = mediaDataCache.padding.top;
    var themeData = Theme.of(context);
    var cardColor = themeData.cardColor;
    var hintColor = themeData.hintColor;
    List<Widget> list = [];

    list.add(Container(
      // margin: EdgeInsets.only(bottom: Base.BASE_PADDING),
      child: Stack(children: [
        Selector<MetadataProvider, Metadata?>(
          builder: (context, metadata, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MetadataTopComponent(
                  pubkey: pubkey,
                  metadata: metadata,
                  isLocal: true,
                  jumpable: true,
                ),
                UserStatisticsComponent(pubkey: pubkey),
              ],
            );
          },
          selector: (context, _provider) {
            return _provider.getMetadata(pubkey);
          },
        ),
        Positioned(
          top: paddingTop + Base.BASE_PADDING_HALF,
          right: Base.BASE_PADDING,
          child: Container(
            height: profileEditBtnWidth,
            width: profileEditBtnWidth,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(profileEditBtnWidth / 2),
            ),
            child: IconButton(
              icon: Icon(Icons.edit_square),
              onPressed: jumpToProfileEdit,
            ),
          ),
        ),
      ]),
    ));

    list.add(IndexDrawerItem(
      iconData: Icons.block,
      name: "Filter",
      onTap: () {
        RouterUtil.router(context, RouterPath.FILTER);
      },
    ));

    list.add(IndexDrawerItem(
      iconData: Icons.cloud,
      name: "Relays",
      onTap: () {
        RouterUtil.router(context, RouterPath.RELAYS);
      },
    ));

    list.add(IndexDrawerItem(
      iconData: Icons.key,
      name: "Key Backup",
      // borderBottom: true,
      onTap: () {
        RouterUtil.router(context, RouterPath.KEY_BACKUP);
      },
    ));

    list.add(IndexDrawerItem(
      iconData: Icons.settings,
      name: "Setting",
      // borderBottom: true,
      onTap: () {},
    ));

    list.add(Expanded(child: Container()));

    list.add(IndexDrawerItem(
      iconData: Icons.logout,
      name: "Sign out",
      onTap: signOut,
    ));

    list.add(Container(
      margin: const EdgeInsets.only(top: Base.BASE_PADDING_HALF),
      padding: const EdgeInsets.only(
        left: Base.BASE_PADDING * 2,
        bottom: Base.BASE_PADDING,
        top: Base.BASE_PADDING,
      ),
      decoration: BoxDecoration(
          border: Border(
              top: BorderSide(
        width: 1,
        color: hintColor,
      ))),
      alignment: Alignment.centerLeft,
      child: Text("V " + Base.VERSION_NAME),
    ));

    return Container(
      child: Column(
        children: list,
      ),
    );
  }

  void jumpToProfileEdit() {
    var metadata = metadataProvider.getMetadata(nostr!.publicKey);
    RouterUtil.router(context, RouterPath.PROFILE_EDITOR, metadata);
  }

  signOut() {
    mentionMeProvider.clear();
    followEventProvider.clear();
    dmProvider.clear();
    noticeProvider.clear();
    contactListProvider.clear();

    eventReactionsProvider.clear();
    linkPreviewDataProvider.clear();
    relayProvider.clear();

    var currentIndex = settingProvider.privateKeyIndex!;
    // remove private key
    settingProvider.removeKey(currentIndex);
    // clear local db
    DMSessionInfoDB.deleteAll(currentIndex);
    EventDB.deleteAll(currentIndex);
    MetadataDB.deleteAll();

    nostr!.close();
    nostr = null;

    // signOut complete
    if (settingProvider.privateKey != null) {
      // use next privateKey to login
      nostr = relayProvider.genNostr(settingProvider.privateKey!);
    }
  }
}

class IndexDrawerItem extends StatelessWidget {
  IconData iconData;

  String name;

  Function onTap;

  // bool borderTop;

  // bool borderBottom;

  IndexDrawerItem({
    required this.iconData,
    required this.name,
    required this.onTap,
    // this.borderTop = true,
    // this.borderBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    var hintColor = themeData.hintColor;
    List<Widget> list = [];

    list.add(Container(
      margin: EdgeInsets.only(
        left: Base.BASE_PADDING * 2,
        right: Base.BASE_PADDING,
      ),
      child: Icon(iconData),
    ));

    list.add(Text(name));

    var borderSide = BorderSide(width: 1, color: hintColor);

    return GestureDetector(
      onTap: () {
        onTap();
      },
      behavior: HitTestBehavior.translucent,
      child: Container(
        height: 34,
        // decoration: BoxDecoration(
        //   border: Border(
        //     top: borderTop ? borderSide : BorderSide.none,
        //     bottom: borderBottom ? borderSide : BorderSide.none,
        //   ),
        // ),
        child: Row(
          children: list,
        ),
      ),
    );
  }
}
