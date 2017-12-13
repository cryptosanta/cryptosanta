// Partial

import java.nio.ByteBuffer;

...

public List<PlayerPayout> draw(String address, byte[] seed, List<Player> players) {

        // seed: 64 random bytes from Oraclize

...

        if (seed.length % 4 != 0) {
            throw new IllegalArgumentException("Seed length must be multiple by 4.");
        }

...

        final int integerItems = seed.length / 4;
        int[] intSeed = new int[integerItems];
        ByteBuffer wrapped = ByteBuffer.wrap(seed);
        for (int i = 0; i < integerItems; i ++) {
            intSeed[i] = wrapped.getInt(i);
        }
        new Solver().draw(address, playerInfos, intSeed);

...
