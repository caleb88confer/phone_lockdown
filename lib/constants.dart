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

// Unlock state (chunk 3 of unlockables pilot)
const kPrefUnlockActiveIndex = 'unlockActiveIndex';
const kPrefUnlockAccumulatedMs = 'unlockAccumulatedMs';
const kPrefUnlockOwned = 'unlockOwnedIds';
const kPrefUnlockPending = 'unlockPendingIds';
const kPrefUnlockOwnedAccents = 'unlockOwnedAccents';
const kPrefUnlockHasInitialized = 'unlockHasInitialized';

// Lock-landing explosion (pixel burst) tuning
const kPrefExplosionSetupMode = 'explosionSetupMode';
const kPrefExplosionCount = 'explosionCount';
const kPrefExplosionShardSize = 'explosionShardSize'; // fixed shard side, logical px
const kPrefExplosionSizeRandom = 'explosionSizeRandom'; // per-shard size deviation
const kPrefExplosionSpeed = 'explosionSpeed'; // standard outward speed (was 'spread')
const kPrefExplosionSpeedRandom = 'explosionSpeedRandom'; // per-shard speed deviation
const kPrefExplosionRadius = 'explosionRadius'; // vanish-ring distance (× of base reach)
const kPrefExplosionSpinRate = 'explosionSpinRate'; // spin animation speed (loops/sec)
const kPrefExplosionSpinRandom = 'explosionSpinRandom'; // per-shard spin deviation
const kPrefExplosionDurationMs = 'explosionDurationMs';
const kPrefExplosionLifetimeRandom = 'explosionLifetimeRandom'; // per-shard lifetime deviation
const kPrefExplosionColors = 'explosionColors'; // comma-separated palette indices
const kPrefExplosionLockPalette = 'explosionLockPalette'; // sample colours from the lock sprite
const kPrefExplosionLightnessBias = 'explosionLightnessBias'; // skew lock palette toward lighter colours
const kPrefExplosionWhiteMix = 'explosionWhiteMix'; // share of shards forced white in lock palette

// Defaults
const kDefaultFailsafeMinutes = 1440;
