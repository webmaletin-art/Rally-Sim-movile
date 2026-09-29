package com.gskorp.rallysim;

import android.graphics.Rect;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import com.getcapacitor.BridgeActivity;
import java.util.ArrayList;
import java.util.List;

/* Pantalla completa inmersiva: sin barra de notificaciones ni botones de Android.
   - Si aparecen (por deslizar desde el borde con el volante o el pedal), se vuelven a esconder solas enseguida.
   - Los bordes de abajo (donde están el volante y el pedal) no disparan el gesto de "atrás" de Android 10+.
   - La pantalla no se apaga mientras se juega. */
public class MainActivity extends BridgeActivity {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private boolean resumed = false;
    private final Runnable keepHidden = new Runnable() {
        @Override public void run() {
            if (!resumed) return;
            if (hasWindowFocus()) immersive();
            handler.postDelayed(this, 2000);
        }
    };

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        immersive();
        final View decor = getWindow().getDecorView();
        /* Android viejo: cuando el sistema muestra las barras, esconderlas de nuevo al rato */
        decor.setOnSystemUiVisibilityChangeListener(vis -> {
            if ((vis & View.SYSTEM_UI_FLAG_FULLSCREEN) == 0 || (vis & View.SYSTEM_UI_FLAG_HIDE_NAVIGATION) == 0) {
                handler.postDelayed(this::immersive, 1200);
            }
        });
        decor.addOnLayoutChangeListener((v, l, t, r, b, ol, ot, or, ob) -> gestureExclusion(v));
    }

    @Override
    public void onResume() {
        super.onResume();
        resumed = true;
        immersive();
        handler.removeCallbacks(keepHidden);
        handler.postDelayed(keepHidden, 2000);
    }

    @Override
    public void onPause() {
        resumed = false;
        handler.removeCallbacks(keepHidden);
        super.onPause();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) immersive();
    }

    /* los controles de manejo están abajo a los costados: ese pedazo de borde no es "atrás" */
    private void gestureExclusion(View v) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return;
        int w = v.getWidth(), h = v.getHeight();
        if (w == 0 || h == 0) return;
        float dp = getResources().getDisplayMetrics().density;
        int edge = (int) (48 * dp), tall = (int) Math.min(h, 200 * dp);
        List<Rect> rects = new ArrayList<>();
        rects.add(new Rect(0, h - tall, edge, h));
        rects.add(new Rect(w - edge, h - tall, w, h));
        v.setSystemGestureExclusionRects(rects);
    }

    @SuppressWarnings("deprecation")
    private void immersive() {
        Window w = getWindow();
        w.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            WindowManager.LayoutParams lp = w.getAttributes();
            lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            w.setAttributes(lp);
        }
        WindowCompat.setDecorFitsSystemWindows(w, false);
        WindowInsetsControllerCompat c = WindowCompat.getInsetsController(w, w.getDecorView());
        c.setSystemBarsBehavior(WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        c.hide(WindowInsetsCompat.Type.systemBars());
        /* también las banderas clásicas (algunos teléfonos solo respetan estas) */
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            w.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
        }
    }
}
