import 'package:flutter/material.dart';
import 'users_service.dart';

Future<String?> showRoleSheet(
    BuildContext context, {
      String? currentRole, // <-- [NÂNG CẤP 1] Thêm tham số này
    }) async {
  final roles = UsersService().supportedRoles();
  String? selected = currentRole; // <-- [NÂNG CẤP 1] Gán giá trị ban đầu

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), // Điều chỉnh padding
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chọn quyền cho người dùng', // Tiêu đề rõ ràng hơn
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          StatefulBuilder(builder: (c, setS) {
            return Wrap(
              spacing: 8,
              runSpacing: 8, // Thêm runSpacing phòng khi có nhiều roles
              children: roles.map((r) {
                final isSelected = selected == r;
                return ChoiceChip(
                  label: Text(r),
                  selected: isSelected,
                  // [NÂNG CẤP 2] Thêm icon check
                  avatar: isSelected
                      ? Icon(
                    Icons.check,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  )
                      : null,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : null,
                  ),
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  onSelected: (v) {
                    selected = r;
                    setS(() {});
                  },
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 24),
          // [NÂNG CẤP 2] Thêm nút "Huỷ" và căn chỉnh lại
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Huỷ'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, selected),
                  child: const Text('Xong'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}