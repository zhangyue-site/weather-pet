package com.weather.companion;

import android.content.Context;
import android.location.Address;
import android.location.Geocoder;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.*;

/** One foreground lookup. No Godot callback or JNI wrapper runs on the worker. */
public final class LocationNameResolver implements AutoCloseable {
    interface Lookup { String resolve(double latitude, double longitude) throws Exception; }
    private final Lookup lookup;
    private final long timeoutMillis;
    private final ThreadPoolExecutor executor;
    private final ScheduledThreadPoolExecutor timer;
    private Future<?> task;
    private ScheduledFuture<?> deadline;
    private int generation;
    private boolean closed;
    private boolean done = true;
    private String name = "";

    public LocationNameResolver(Context context) {
        this((lat, lon) -> {
            if (!Geocoder.isPresent()) return "";
            @SuppressWarnings("deprecation")
            List<Address> addresses = new Geocoder(context.getApplicationContext(), Locale.SIMPLIFIED_CHINESE)
                    .getFromLocation(lat, lon, 1);
            if (addresses == null || addresses.isEmpty()) return "";
            Address address = addresses.get(0);
            String city = address.getLocality();
            if (city == null || city.trim().isEmpty()) city = address.getAdminArea();
            String district = address.getSubLocality();
            if (district == null || district.trim().isEmpty()) district = address.getSubAdminArea();
            city = city == null ? "" : city.trim();
            district = district == null ? "" : district.trim();
            return city.isEmpty() ? district : district.isEmpty() || district.equals(city) ? city : city + " · " + district;
        }, 8000);
    }

    LocationNameResolver(Lookup lookup, long timeoutMillis) {
        this.lookup = lookup;
        this.timeoutMillis = timeoutMillis;
        ThreadFactory threads = work -> {
            Thread thread = new Thread(work, "WeatherPlace");
            thread.setDaemon(true);
            return thread;
        };
        executor = new ThreadPoolExecutor(1, 1, 0, TimeUnit.MILLISECONDS,
                new LinkedBlockingQueue<Runnable>(), threads);
        timer = new ScheduledThreadPoolExecutor(1, threads);
        timer.setRemoveOnCancelPolicy(true);
    }

    public synchronized void start(double latitude, double longitude) {
        cancel();
        if (closed || Double.isNaN(latitude) || Double.isInfinite(latitude) || Double.isNaN(longitude) || Double.isInfinite(longitude)
                || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return;
        final int token = generation;
        done = false;
        final Future<?> request = executor.submit(() -> {
            String result = "";
            try { result = lookup.resolve(latitude, longitude); }
            catch (Exception ignored) { /* Unavailable/denied geocoding must not stop the app. */ }
            synchronized (LocationNameResolver.this) {
                if (generation == token && !closed && !done) {
                    name = result == null ? "" : result;
                    done = true;
                }
            }
        });
        task = request;
        deadline = timer.schedule(() -> {
            synchronized (LocationNameResolver.this) {
                if (generation == token && !closed && !done) {
                    name = "";
                    done = true;
                    request.cancel(true);
                }
            }
        }, timeoutMillis, TimeUnit.MILLISECONDS);
    }

    public synchronized boolean isDone() { return done; }
    public synchronized String getName() { return name; }
    public synchronized void cancel() {
        generation++;
        done = true;
        name = "";
        if (task != null) { task.cancel(true); task = null; }
        if (deadline != null) { deadline.cancel(false); deadline = null; }
        executor.purge();
    }
    @Override public synchronized void close() {
        if (closed) return;
        cancel();
        closed = true;
        executor.shutdownNow();
        timer.shutdownNow(); // Never await termination of an OS geocoder call.
    }
}
