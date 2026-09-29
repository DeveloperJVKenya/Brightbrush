import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/currency.dart';
import '../application/commerce_providers.dart';
import '../data/commerce_repository.dart';

/// Profile section for customers: their business terms (if an admin set
/// any) and a downloadable account statement.
class CustomerAccountTile extends ConsumerWidget {
  const CustomerAccountTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(myAccountProvider).valueOrNull;
    final terms = <String>[
      if (account?.companyName.isNotEmpty == true) account!.companyName,
      if ((account?.discountPercent ?? 0) > 0)
        '${account!.discountPercent}% account discount',
      if (account?.creditEnabled == true)
        'Pay on account, ${account!.paymentTermsDays}-day terms'
            '${account.creditLimit > 0 ? ' (limit ${currencyFormat.format(account.creditLimit)})' : ''}',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            if (terms.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.business_center_outlined),
                title: const Text('Business account'),
                subtitle: Text(terms.join(' · ')),
              ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Account statement'),
              subtitle: const Text(
                'All your invoices, payments and balance (PDF)',
              ),
              trailing: const Icon(Icons.download_rounded),
              onTap: () =>
                  openDocument(context, ref, DocumentKind.statement, null),
            ),
          ],
        ),
      ),
    );
  }
}
