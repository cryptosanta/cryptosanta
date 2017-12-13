package com.dream;

import java.math.BigInteger;
import java.util.*;

import static com.dream.Util.asEth;
import static com.dream.Util.debug;
import static com.dream.Util.info;

@SuppressWarnings("WeakerAccess")
public class Solver {

    /**
     * To enter the draw, the dream wei has to be at least the purchased wei multiplied by this coefficient.
     */
    private static final int MIN_DREAM_TO_PURCHASED_RATIO = 0; // Was 3

    /**
     * {@code true}, if winner's refund should be kept in the bank for futher rounds,
     * {@code false}, if winner's refund should go to the organizer's commission.
     */
    static boolean keepWinnerRefundInBank = false;

    /**
     * Random number generator.
     */
    private Rnd rnd = null;

    /**
     * Active players.
     */
    private List<PlayerInfo> activePlayers = null;

    /**
     * Players ended their participation in the draw.
     */
    private List<PlayerInfo> donePlayers = null;

    /**
     * Bank size in wei.
     */
    private BigInteger bankWei = null;

    /**
     * Commission in wei.
     */
    private BigInteger commissionWei = null;

    /**
     * Make a draw, determine payouts for all players and the remainder left for the organizer.
     * The order of entries in playerInfos may change.
     *
     * @param lotteryAddress an address of the smart-contract of the lottery instance
     * @param playerInfos a list of players' info with the purchased wei and the dream wei
     *                    for each player
     * @param integerSeed        a random seed
     * @return the remainder left for the organizer
     */
    public BigInteger draw(final String lotteryAddress, final List<PlayerInfo> playerInfos, final int[] integerSeed) {
        if (lotteryAddress != null) Util.instanceId = lotteryAddress;
        if (playerInfos.isEmpty()) {
            info(() -> "There are no players. Total commission = 0.");
            return BigInteger.ZERO;
        }
        printPlayerInfos("Unsorted players", playerInfos);
        bankWei = BigInteger.ZERO;
        for (final PlayerInfo playerInfo : playerInfos) {
            bankWei = bankWei.add(playerInfo.purchasedWei);
        }
        commissionWei = BigInteger.ZERO;
        final BigInteger initialBankWei = bankWei;
        info(() -> "Initial bank = " + asEth(initialBankWei));
        if (playerInfos.size() == 1) {
            info(() -> "A unique player gets the funds back. Total commission = 0.");
            final PlayerInfo playerInfo = playerInfos.get(0);
            playerInfo.payoutWei = playerInfo.purchasedWei;
            bankWei = null;
            return BigInteger.ZERO;
        }
        defineActiveAndDonePlayers(playerInfos);
        if (activePlayers.isEmpty()) {
            info(() -> "No players left for a draw. Total commission = 0.");
            commissionWei = commissionWei.add(bankWei);
            bankWei = null;
            return commissionWei; // should be zero
        }
        int round = 0;
        while (!activePlayers.isEmpty()) {
            conductRound(++round, integerSeed);
        }
        final BigInteger finalBankWei = bankWei;
        info(() -> "Final bank = " + asEth(finalBankWei));
        commissionWei = commissionWei.add(bankWei);
        bankWei = null;
        final BigInteger totalCommissionWei = commissionWei;
        info(() -> "Total commission = " + asEth(totalCommissionWei));
        playerInfos.sort(Comparator.comparing(o -> o.payoutWei, Comparator.reverseOrder()));
        printPlayerInfos("Sorted players", playerInfos);
        return commissionWei;
    }

    private void printPlayerInfos(final String label, final List<PlayerInfo> playerInfos) {
        info(() -> label + " begin");
        for (final PlayerInfo playerInfo : playerInfos) {
            info(() -> "Player " + playerInfo.playerId
                    + ": purchased "
                    + asEth(playerInfo.purchasedWei)
                    + ", dream "
                    + asEth(playerInfo.dreamWei)
                    + ", payout "
                    + asEth(playerInfo.payoutWei) + ".");
        }
        info(() -> label + " end");
    }

    private void defineActiveAndDonePlayers(final List<PlayerInfo> playerInfos) {
        activePlayers = new ArrayList<>();
        donePlayers = new ArrayList<>();
        Util.splitByCondition(playerInfos,
                player -> (player.purchasedWei.multiply(BigInteger.valueOf(MIN_DREAM_TO_PURCHASED_RATIO)).compareTo(player.dreamWei) <= 0),
                activePlayers,
                donePlayers);
        for (final PlayerInfo playerInfo : donePlayers) {
            playerInfo.payoutWei = playerInfo.purchasedWei;
            bankWei = bankWei.subtract(playerInfo.payoutWei);
            debug(() -> playerInfo + " has too small ratio of dream to purchased wei.");
        }
        for (final PlayerInfo playerInfo : activePlayers) {
            playerInfo.x = playerInfo.purchasedWei;
        }
        if (!activePlayers.isEmpty()) {
            activePlayers.sort(Comparator.comparing(o -> o.dreamWei));
        }
    }

    /**
     * Get the commission deducted from the bank, when a player wins.
     *
     * @param amountWei amount won
     * @return commission deducted
     */
    private static BigInteger getCommissionWei(final BigInteger amountWei) {
        // If a player wins amountWei, the commission is floor(amountWei / 5).
        return amountWei.divide(BigInteger.valueOf(5));
    }

    private void conductRound(final int round, final int[] integerSeed) {
        info(() -> "Round #" + round + ", bank = " + asEth(bankWei) + ".");
        removePlayersUnableToWin();
        if (activePlayers.isEmpty()) {
            info(() -> "No active players left for the round.");
            return;
        }
        info(() -> "Bank = " + asEth(bankWei) + ".");
        activePlayers.forEach(PlayerInfo::updateWeight);
        final BigInteger bankBeforeRound = bankWei;
        ensureRnd(integerSeed);
        final int winnerId = getWinnerId();
        final PlayerInfo winner = activePlayers.remove(winnerId);
        bankWei = bankWei.subtract(winner.dreamWei);
        winner.payoutWei = winner.dreamWei;
        info(() -> winner + " won " + asEth(winner.payoutWei) + ".");
        final BigInteger dreamCommissionWei = getCommissionWei(winner.dreamWei);
        bankWei = bankWei.subtract(dreamCommissionWei);
        commissionWei = commissionWei.add(dreamCommissionWei);
        debug(() -> "The dream commission of " + asEth(dreamCommissionWei) + " goes to the organizers.");
        final BigInteger winnerRefund = keepWinnerRefundInBank ?
                BigInteger.ZERO : bankWei.multiply(winner.x).divide(bankBeforeRound);
        winner.x = null;
        donePlayers.add(winner);
        for (final PlayerInfo playerInfo : activePlayers) {
            playerInfo.x = bankWei.multiply(playerInfo.x).divide(bankBeforeRound);
            debug(() -> playerInfo + " refunded by " + asEth(playerInfo.x) + ".");
        }
        debug(() -> "Winner's refund " + asEth(winnerRefund) + " goes to the organizers.");
        bankWei = bankWei.subtract(winnerRefund);
        commissionWei = commissionWei.add(winnerRefund);
    }

    private void removePlayersUnableToWin() {
        for (int i = activePlayers.size() - 1; i >= 0; i--) {
            final PlayerInfo playerInfo = activePlayers.get(i);
            final BigInteger dreamPlusCommission = playerInfo.dreamWei.add(getCommissionWei(playerInfo.dreamWei));
            if (dreamPlusCommission.compareTo(bankWei) > 0) {
                activePlayers.remove(i);
                playerInfo.payoutWei = playerInfo.x;
                playerInfo.x = null;
                bankWei = bankWei.subtract(playerInfo.payoutWei);
                donePlayers.add(playerInfo);
                debug(() -> playerInfo + " has an impossible dream in this round.");
            } else {
                break;
            }
        }
    }

    private void ensureRnd(final int[] integerSeed) {
        if (rnd == null) {
            debug(() -> "Integer seed items: " + integerSeed.length);
            debug(() -> "Initialize the random generator: seed = " + Arrays.toString(integerSeed));
            rnd = new RndImpl();
            rnd.setIntegerSeed(integerSeed);
        }
    }

    private int getWinnerId() {
        double sum = 0;
        for (final PlayerInfo playerInfo : activePlayers) {
            sum += playerInfo.weight;
        }
        final double bound = rnd.nextDouble() * sum;
        sum = 0;
        for (int i = 0; i < activePlayers.size(); i++) {
            final PlayerInfo playerInfo = activePlayers.get(i);
            sum += playerInfo.weight;
            if (sum >= bound) {
                return i;
            }
        }
        // Cannot get here since bound does not exceed the sum of all weights
        throw new IllegalStateException("Could not get a winner.");
    }
}
