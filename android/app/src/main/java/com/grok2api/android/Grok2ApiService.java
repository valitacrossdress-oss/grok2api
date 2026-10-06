package com.grok2api.android;

import android.app.Notification;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.os.Binder;
import android.os.Build;
import android.os.IBinder;
import androidx.core.app.NotificationCompat;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

public class Grok2ApiService extends Service {
    private static final int NOTIFICATION_ID = 1;
    private Process serverProcess;
    private File configFile;
    private File dataDir;
    private File logFile;
    private final IBinder binder = new LocalBinder();
    private boolean isRunning = false;

    public class LocalBinder extends Binder {
        public Grok2ApiService getService() {
            return Grok2ApiService.this;
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        // Initialize directories
        dataDir = new File(getFilesDir(), "grok2api");
        if (!dataDir.exists()) {
            dataDir.mkdirs();
        }
        
        File configDir = new File(dataDir, "config");
        if (!configDir.exists()) {
            configDir.mkdirs();
        }
        
        configFile = new File(configDir, "config.yaml");
        logFile = new File(dataDir, "server.log");
        
        // Extract assets if needed
        extractAssets();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && intent.getAction() != null) {
            if (intent.getAction().equals("START")) {
                startServer();
            } else if (intent.getAction().equals("STOP")) {
                stopServer();
            }
        }
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return binder;
    }

    public boolean isServerRunning() {
        return isRunning && serverProcess != null;
    }

    public String getServerStatus() {
        if (isServerRunning()) {
            return "Running on port 8000";
        }
        return "Stopped";
    }

    public void startServer() {
        if (isServerRunning()) {
            return;
        }

        new Thread(() -> {
            try {
                // Check if config exists, create from example if not
                File exampleConfig = new File(getFilesDir(), "config.example.yaml");
                if (!configFile.exists() && exampleConfig.exists()) {
                    copyFile(exampleConfig, configFile);
                }

                // Check if binary exists
                File binary = new File(getFilesDir(), "grok2api");
                if (!binary.exists()) {
                    // Try to extract from assets
                    extractBinary();
                    binary = new File(getFilesDir(), "grok2api");
                }

                if (!binary.exists()) {
                    updateStatus("Binary not found. Please install it first.");
                    return;
                }

                // Make binary executable
                binary.setExecutable(true);

                // Build command
                List<String> command = new ArrayList<>();
                command.add(binary.getAbsolutePath());
                command.add("--config");
                command.add(configFile.getAbsolutePath());
                command.add("--listen");
                command.add("127.0.0.1:8000");

                ProcessBuilder processBuilder = new ProcessBuilder(command);
                processBuilder.directory(dataDir);
                processBuilder.redirectErrorStream(true);
                processBuilder.redirectOutput(ProcessBuilder.Redirect.appendTo(logFile));
                
                serverProcess = processBuilder.start();
                isRunning = true;
                
                updateStatus("Server started successfully");
                showNotification();
                
            } catch (IOException e) {
                updateStatus("Error starting server: " + e.getMessage());
                isRunning = false;
            }
        }).start();
    }

    public void stopServer() {
        if (!isServerRunning()) {
            return;
        }

        if (serverProcess != null) {
            serverProcess.destroy();
            try {
                serverProcess.waitFor();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            serverProcess = null;
        }
        isRunning = false;
        updateStatus("Server stopped");
        stopForeground(true);
    }

    private void extractAssets() {
        try {
            String[] files = getAssets().list("");
            if (files != null) {
                for (String file : files) {
                    File outFile = new File(getFilesDir(), file);
                    if (!outFile.exists()) {
                        copyAsset(file, outFile);
                    }
                }
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void extractBinary() {
        try {
            copyAsset("grok2api", new File(getFilesDir(), "grok2api"));
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void copyAsset(String assetName, File outFile) throws IOException {
        InputStream in = getAssets().open(assetName);
        OutputStream out = new FileOutputStream(outFile);
        byte[] buffer = new byte[1024];
        int read;
        while ((read = in.read(buffer)) != -1) {
            out.write(buffer, 0, read);
        }
        in.close();
        out.flush();
        out.close();
    }

    private void copyFile(File src, File dst) throws IOException {
        InputStream in = new java.io.FileInputStream(src);
        OutputStream out = new FileOutputStream(dst);
        byte[] buffer = new byte[1024];
        int read;
        while ((read = in.read(buffer)) != -1) {
            out.write(buffer, 0, read);
        }
        in.close();
        out.flush();
        out.close();
    }

    private void showNotification() {
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
                this, 0, notificationIntent, 
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? 
                        PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT : 
                        PendingIntent.FLAG_UPDATE_CURRENT
        );

        Notification notification = new NotificationCompat.Builder(this, Grok2ApiApp.CHANNEL_ID)
                .setContentTitle(getString(R.string.app_name))
                .setContentText(getString(R.string.notification_text, 8000))
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build();

        startForeground(NOTIFICATION_ID, notification);
    }

    private void updateStatus(String message) {
        Intent intent = new Intent("com.grok2api.android.STATUS_UPDATE");
        intent.putExtra("status", message);
        sendBroadcast(intent);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        stopServer();
    }
}
