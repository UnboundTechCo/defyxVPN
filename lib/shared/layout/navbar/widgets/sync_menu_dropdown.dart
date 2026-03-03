import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/quick_menu_item.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SyncMenuDropdown extends ConsumerStatefulWidget {
  const SyncMenuDropdown({super.key});

  @override
  ConsumerState<SyncMenuDropdown> createState() => _SyncMenuDropdownState();
}

class _SyncMenuDropdownState extends ConsumerState<SyncMenuDropdown>
    with SingleTickerProviderStateMixin {
  final AnimationService _animationService = AnimationService();
  final MenuController _menuController = MenuController();
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: _animationService.adjustDuration(
        const Duration(milliseconds: 500),
      ),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menuController,
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(const Color(0xFFd1d1d1)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
        elevation: WidgetStateProperty.all(8),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
      ),
      consumeOutsideTap: true,
      alignmentOffset: Offset(0, 8),
      useRootOverlay: true,
      menuChildren: [
        SizedBox(
          width: 230.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QuickMenuItem(
                topBorderRadius: true,
                title: 'Update Methods',
                titleStyle: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                icon: Icon(
                  Icons.refresh,
                  size: 20.sp,
                  color: const Color(0xFF7B7B7B),
                ),
                onTap: () async {
                  _menuController.close();
                  if (_animationService.shouldAnimate()) {
                    _rotationController.forward().then((_) {
                      _rotationController.reset();
                    });
                  }
                  await ref.read(flowlineServiceProvider).saveFlowline(loadFromCache: false);
                  ref
                      .read(settingsProvider.notifier)
                      .updateSettingsBasedOnFlowLine();
                },
              ),
              Divider(
                height: 1.h,
                thickness: 1,
                color: const Color(0x8080808C),
              ),
              QuickMenuItem(
                title: 'Import API',
                titleStyle: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                icon: AppIcons.importAPI(width: 20, height: 20),
                onTap: () {
                  FilePicker.platform
                      .pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['json'],
                      )
                      .then((result) async {
                        if (result != null &&
                            result.files.single.path != null) {
                          ref
                              .read(flowlineServiceProvider)
                              .saveFlowline(
                                loadFromCache: false,
                                flowLine: await result.xFiles.first
                                    .readAsString(),
                              );
                        }
                      });
                  _menuController.close();
                },
              ),
            ],
          ),
        ),
      ],
      builder: (context, controller, child) {
        return GestureDetector(
          onTap: () {
            if (_menuController.isOpen) {
              _menuController.close();
            } else {
              _menuController.open();
            }
          },
          child: child,
        );
      },
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value * 2 * 3.14159,
                child: child,
              );
            },
            child: Icon(
              Icons.cached,
              size: 20.sp,
              color: const Color(0xFFD5FFBA),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            'Synchronization'.toUpperCase(),
            style: TextStyle(
              fontSize: 12.sp,
              fontFamily: 'Lato',
              fontWeight: FontWeight.w600,
              color: const Color(0xFFD5FFBA),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
