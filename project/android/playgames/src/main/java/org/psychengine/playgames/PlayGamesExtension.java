package org.psychengine.playgames;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

import com.google.android.gms.games.AchievementsClient;
import com.google.android.gms.games.AuthenticationResult;
import com.google.android.gms.games.GamesSignInClient;
import com.google.android.gms.games.LeaderboardsClient;
import com.google.android.gms.games.PlayGames;
import com.google.android.gms.games.PlayGamesSdk;
import com.google.android.gms.games.Player;
import com.google.android.gms.tasks.Task;

import org.haxe.extension.Extension;

import java.util.concurrent.ConcurrentLinkedQueue;

public class PlayGamesExtension extends Extension
{
	private static final int REQUEST_ACHIEVEMENTS = 0x5047;
	private static final int REQUEST_LEADERBOARD = 0x5048;

	private static final ConcurrentLinkedQueue<String> events = new ConcurrentLinkedQueue<>();
	private static volatile boolean initialized = false;
	private static volatile boolean authenticated = false;
	private static volatile boolean busy = false;
	private static volatile String playerId = "";
	private static volatile String playerName = "";

	@Override
	public void onCreate(Bundle savedInstanceState)
	{
		initialize();
	}

	@Override
	public void onResume()
	{
		if (initialized && !authenticated) checkAuthentication();
	}

	public static boolean isConfigured()
	{
		Context context = Extension.mainContext;
		if (context == null) return false;
		int id = context.getResources().getIdentifier("psych_play_games_app_id", "string", context.getPackageName());
		if (id == 0) return false;
		String value = context.getString(id);
		return value != null && !value.isEmpty() && !value.equals("0");
	}

	public static boolean initialize()
	{
		if (initialized) return true;
		Context context = Extension.mainContext;
		if (context == null || !isConfigured()) return false;
		try
		{
			PlayGamesSdk.initialize(context);
			initialized = true;
			checkAuthentication();
		}
		catch (Throwable error)
		{
			push("error", "init:" + error.getMessage());
		}
		return initialized;
	}

	public static boolean isInitialized()
	{
		return initialized;
	}

	public static boolean isAuthenticated()
	{
		return authenticated;
	}

	public static boolean isBusy()
	{
		return busy;
	}

	public static String getPlayerId()
	{
		return playerId;
	}

	public static String getPlayerName()
	{
		return playerName;
	}

	public static String pollEvent()
	{
		String event = events.poll();
		return event == null ? "" : event;
	}

	public static void checkAuthentication()
	{
		final Activity activity = Extension.mainActivity;
		if (!initialized || activity == null) return;
		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					GamesSignInClient client = PlayGames.getGamesSignInClient(activity);
					client.isAuthenticated().addOnCompleteListener(task -> handleAuthentication(activity, task, false));
				}
				catch (Throwable error)
				{
					push("error", "auth:" + error.getMessage());
				}
			}
		});
	}

	public static void signIn()
	{
		final Activity activity = Extension.mainActivity;
		if (!initialize() || activity == null || busy) return;
		busy = true;
		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					GamesSignInClient client = PlayGames.getGamesSignInClient(activity);
					client.signIn().addOnCompleteListener(task -> handleAuthentication(activity, task, true));
				}
				catch (Throwable error)
				{
					busy = false;
					push("error", "signin:" + error.getMessage());
				}
			}
		});
	}

	private static void handleAuthentication(Activity activity, Task<AuthenticationResult> task, boolean manual)
	{
		busy = false;
		boolean success = task.isSuccessful() && task.getResult() != null && task.getResult().isAuthenticated();
		if (!success)
		{
			boolean was = authenticated;
			authenticated = false;
			if (was) push("signout", "");
			if (manual) push("error", "signin:" + (task.getException() != null ? task.getException().getMessage() : "cancelled"));
			return;
		}
		authenticated = true;
		try
		{
			PlayGames.getPlayersClient(activity).getCurrentPlayer().addOnCompleteListener(playerTask -> {
				if (playerTask.isSuccessful() && playerTask.getResult() != null)
				{
					Player player = playerTask.getResult();
					playerId = player.getPlayerId();
					playerName = player.getDisplayName();
				}
				push("signin", playerId + "\t" + playerName);
			});
		}
		catch (Throwable error)
		{
			push("signin", "\t");
		}
	}

	private static AchievementsClient achievements()
	{
		Activity activity = Extension.mainActivity;
		if (!initialized || !authenticated || activity == null) return null;
		return PlayGames.getAchievementsClient(activity);
	}

	private static LeaderboardsClient leaderboards()
	{
		Activity activity = Extension.mainActivity;
		if (!initialized || !authenticated || activity == null) return null;
		return PlayGames.getLeaderboardsClient(activity);
	}

	public static boolean unlockAchievement(final String id)
	{
		return runOnUi(() -> {
			AchievementsClient client = achievements();
			if (client != null) client.unlock(id);
		});
	}

	public static boolean incrementAchievement(final String id, final int steps)
	{
		return runOnUi(() -> {
			AchievementsClient client = achievements();
			if (client != null && steps > 0) client.increment(id, steps);
		});
	}

	public static boolean setAchievementSteps(final String id, final int steps)
	{
		return runOnUi(() -> {
			AchievementsClient client = achievements();
			if (client != null && steps > 0) client.setSteps(id, steps);
		});
	}

	public static boolean revealAchievement(final String id)
	{
		return runOnUi(() -> {
			AchievementsClient client = achievements();
			if (client != null) client.reveal(id);
		});
	}

	public static boolean submitScore(final String id, final double score)
	{
		return runOnUi(() -> {
			LeaderboardsClient client = leaderboards();
			if (client != null) client.submitScore(id, (long) score);
		});
	}

	public static boolean showAchievements()
	{
		return runOnUi(() -> {
			AchievementsClient client = achievements();
			if (client == null) return;
			client.getAchievementsIntent().addOnSuccessListener(intent -> start(intent, REQUEST_ACHIEVEMENTS));
		});
	}

	public static boolean showLeaderboard(final String id)
	{
		return runOnUi(() -> {
			LeaderboardsClient client = leaderboards();
			if (client == null) return;
			Task<Intent> task = id == null || id.isEmpty() ? client.getAllLeaderboardsIntent() : client.getLeaderboardIntent(id);
			task.addOnSuccessListener(intent -> start(intent, REQUEST_LEADERBOARD));
		});
	}

	private static void start(Intent intent, int request)
	{
		Activity activity = Extension.mainActivity;
		if (activity == null || intent == null) return;
		try
		{
			activity.startActivityForResult(intent, request);
		}
		catch (Throwable error)
		{
			push("error", "ui:" + error.getMessage());
		}
	}

	private static boolean runOnUi(final Runnable action)
	{
		Activity activity = Extension.mainActivity;
		if (!initialized || !authenticated || activity == null) return false;
		activity.runOnUiThread(() -> {
			try
			{
				action.run();
			}
			catch (Throwable error)
			{
				push("error", "call:" + error.getMessage());
			}
		});
		return true;
	}

	private static void push(String type, String data)
	{
		if (events.size() > 64) events.poll();
		events.add(type + "\n" + (data == null ? "" : data));
	}
}
