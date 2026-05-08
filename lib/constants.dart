// Method channel
const kMethodChannel = 'app.phonelockdown/blocker';

// SharedPreferences keys
const kPrefSavedProfiles = 'savedProfiles';
const kPrefCurrentProfileId = 'currentProfileId';
const kPrefActiveLocks = 'activeLocks';
const kPrefIsBlocking = 'isBlocking';

// Master key state
const kPrefMasterKeyCount = 'masterKeyCount';
const kPrefMasterKeyTotalMs = 'masterKeyTotalMs';
const kPrefMasterKeyProgressMs = 'masterKeyProgressMs';
const kPrefMasterKeySessionStartMs = 'masterKeySessionStartMs';
const kPrefMasterKeyHasInitialized = 'masterKeyHasInitialized';

const kMasterKeyMaxCount = 3;
const kMasterKeyAwardMs = 40 * 60 * 60 * 1000; // 40 hours
const kMasterKeyTickSeconds = 30;

// Defaults
const kDefaultFailsafeMinutes = 1440;
