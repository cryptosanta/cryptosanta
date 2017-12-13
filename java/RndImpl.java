package com.dream;

import org.apache.commons.math3.random.Well512a;

/**
 * An implementation of a pseudo random number generator.
 */
public class RndImpl implements Rnd {

    static final int WELL512A_REQUIRED_INTEGER_SEED_ITEMS = 16;

    /**
     * WELL512a pseudo-random number generator.
     * http://commons.apache.org/proper/commons-math/javadocs/api-3.6.1/org/apache/commons/math3/random/Well512a.html
     */
    private final Well512a well512a = new Well512a();

    private int[] integerSeed = null;

    /**
     * Reinitialize the generator as if just built with the given int array seed.
     * The state of the generator is exactly the same as a new generator built with the same seed.
     *
     * @param integerSeed the initial seed (32 bits integers array), if null the seed of the generator will be related to the current time
     */
    public void setIntegerSeed(final int[] integerSeed) {
        if (integerSeed == null) {
            throw new IllegalArgumentException("The seed array is null.");
        }
        /*
        if (integerSeed.length != WELL512A_REQUIRED_INTEGER_SEED_ITEMS) {
            throw new IllegalArgumentException("The seed array must contain " + WELL512A_REQUIRED_INTEGER_SEED_ITEMS + " integer items.");
        }
        */
        this.integerSeed = integerSeed;
        this.well512a.setSeed(integerSeed);
    }

    @Override
    public double nextDouble() {
        if (integerSeed == null) {
            throw new IllegalStateException("A seed not set yet.");
        }
        return well512a.nextDouble();
    }
}
