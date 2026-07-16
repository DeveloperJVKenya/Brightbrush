/// The account that started this system. Every subsequent developer account
/// (if any) is delegated by this uid via Role Management — see
/// firestore.rules' `isFoundingDeveloper()`, which only this uid ever
/// satisfies. No account, including a delegated developer, can grant the
/// `developer` role to anyone else, and nobody (not even this account
/// itself) can ever change *this* account's own role.
const String foundingDeveloperUid = 'ZQ1sVcS9YfbmyLv8m8gBdFiiVD83';
