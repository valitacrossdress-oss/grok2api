package com.grok2api.android;

import android.Manifest;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.IBinder;
import android.provider.Settings;
import android.util.Log;
import android.view.View;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

public class MainActivity extends AppCompatActivity {
    private static final int REQUEST_CODE_PERMISSIONS = 100;
    private static final String[] REQUIRED_PERMISSIONS = {
            Manifest.permission.INTERNET,
            Manifest.permission.ACCESS_NETWORK_STATE,
            Manifest.permission.FOREGROUND_SERVICE
    };
    
    private Grok2ApiService grok2ApiService;
    private boolean isBound = false;
    private TextView statusText;
    private WebView webView;
    
    private final ServiceConnection serviceConnection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder service) {
            Grok2ApiService.LocalBinder binder = (Grok2ApiService.LocalBinder) service;
            grok2ApiService = binder.getService();
            isBound = true;
            updateStatus();
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            grok2ApiService = null;
            isBound = false;
        }
    };

    private final BroadcastReceiver statusReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if ("com.grok2api.android.STATUS_UPDATE".equals(intent.getAction())) {
                updateStatus();
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        statusText = findViewById(R.id.status_text);
        Button startButton = findViewById(R.id.start_button);
        Button stopButton = findViewById(R.id.stop_button);
        Button openConsoleButton = findViewById(R.id.open_console_button);
        Button viewLogsButton = findViewById(R.id.view_logs_button);
        webView = findViewById(R.id.webview);

        // Set up WebView
        webView.getSettings().setJavaScriptEnabled(true);
        webView.getSettings().setDomStorageEnabled(true);
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(android.webkit.WebView view, String url) {
                view.loadUrl(url);
                return true;
            }
        });

        // Button click listeners
        startButton.setOnClickListener(v -> startServer());
        stopButton.setOnClickListener(v -> stopServer());
        openConsoleButton.setOnClickListener(v -> openConsole());
        viewLogsButton.setOnClickListener(v -> viewLogs());

        // Check and request permissions
        checkPermissions();

        // Start and bind the service
        Intent serviceIntent = new Intent(this, Grok2ApiService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent);
        } else {
            startService(serviceIntent);
        }
        bindService(serviceIntent, serviceConnection, Context.BIND_AUTO_CREATE);

        // Register broadcast receiver
        registerReceiver(statusReceiver, new IntentFilter("com.grok2api.android.STATUS_UPDATE"));

        // Extract default config if needed
        extractDefaultConfig();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (isBound) {
            unbindService(serviceConnection);
            isBound = false;
        }
        unregisterReceiver(statusReceiver);
    }

    private void checkPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            boolean allGranted = true;
            for (String permission : REQUIRED_PERMISSIONS) {
                if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
                    allGranted = false;
                    break;
                }
            }
            if (!allGranted) {
                ActivityCompat.requestPermissions(this, REQUIRED_PERMISSIONS, REQUEST_CODE_PERMISSIONS);
            }
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            boolean allGranted = true;
            for (int result : grantResults) {
                if (result != PackageManager.PERMISSION_GRANTED) {
                    allGranted = false;
                    break;
                }
            }
            if (!allGranted) {
                Toast.makeText(this, R.string.error_permission_denied, Toast.LENGTH_LONG).show();
            }
        }
    }

    private void extractDefaultConfig() {
        try {
            File configDir = new File(getFilesDir(), "grok2api/config");
            File configFile = new File(configDir, "config.yaml");
            
            if (!configFile.exists()) {
                // Try to copy from assets
                try {
                    InputStream in = getAssets().open("config.example.yaml");
                    OutputStream out = new FileOutputStream(configFile);
                    byte[] buffer = new byte[1024];
                    int read;
                    while ((read = in.read(buffer)) != -1) {
                        out.write(buffer, 0, read);
                    }
                    in.close();
                    out.flush();
                    out.close();
                    Toast.makeText(this, "Default config created", Toast.LENGTH_SHORT).show();
                } catch (IOException e) {
                    // Config not in assets, will need to be created manually
                    Log.e("Grok2Api", "Config example not found in assets", e);
                }
            }
        } catch (Exception e) {
            Log.e("Grok2Api", "Error extracting config", e);
        }
    }

    private void startServer() {
        if (grok2ApiService != null) {
            grok2ApiService.startServer();
            updateStatus();
        } else {
            Toast.makeText(this, "Service not connected", Toast.LENGTH_SHORT).show();
        }
    }

    private void stopServer() {
        if (grok2ApiService != null) {
            grok2ApiService.stopServer();
            updateStatus();
        } else {
            Toast.makeText(this, "Service not connected", Toast.LENGTH_SHORT).show();
        }
    }

    private void openConsole() {
        if (grok2ApiService != null && grok2ApiService.isServerRunning()) {
            webView.setVisibility(View.VISIBLE);
            webView.loadUrl("http://127.0.0.1:8000");
        } else {
            Toast.makeText(this, "Server is not running. Start it first.", Toast.LENGTH_SHORT).show();
        }
    }

    private void viewLogs() {
        File logFile = new File(getFilesDir(), "grok2api/server.log");
        if (logFile.exists()) {
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(Uri.fromFile(logFile), "text/plain");
            startActivity(intent);
        } else {
            Toast.makeText(this, "No log file found", Toast.LENGTH_SHORT).show();
        }
    }

    private void updateStatus() {
        if (grok2ApiService != null && isBound) {
            String status = grok2ApiService.getServerStatus();
            statusText.setText(status);
        } else {
            statusText.setText("Connecting to service...");
        }
    }
}
