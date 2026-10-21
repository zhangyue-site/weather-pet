package com.weather.companion.tests;
import android.app.*;
import android.content.*;
import android.os.Bundle;
import java.io.*;
import java.lang.reflect.*;
import java.security.MessageDigest;
import org.json.JSONObject;

/** Instrumentation exercises the installed native updater, not a duplicate implementation. */
public final class OtaChecks extends Instrumentation {
  int checks=0;
  boolean network=false;
  public void onCreate(Bundle b) { super.onCreate(b); network="true".equals(b.getString("network")); start(); }
  void expect(boolean value,String message) { if(!value) throw new AssertionError(message); checks++; }
  void rejects(Method m,Object target,Object... args) throws Exception {
    try { m.invoke(target,args); throw new AssertionError("Expected rejection: "+m.getName()); }
    catch(InvocationTargetException e) { expect(e.getCause() instanceof IllegalArgumentException,"Validation error"); }
  }
  void awaitIdle(Class<?> type,Object updater,long timeout) throws Exception {
    Field busy=type.getDeclaredField("busy");busy.setAccessible(true);
    long deadline=System.currentTimeMillis()+timeout;
    while(busy.getBoolean(updater)) {
      if(System.currentTimeMillis()>deadline)throw new AssertionError("Updater timed out");
      Thread.sleep(100);
    }
  }
  public void onStart() {
    Bundle result=new Bundle();
    try {
      Intent launch=new Intent().setClassName("com.weather.companion","com.godot.game.GodotApp").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
      Activity activity=startActivitySync(launch);
      Object registry=Class.forName("org.godotengine.godot.plugin.GodotPluginRegistry").getMethod("getPluginRegistry").invoke(null);
      Object updater=registry.getClass().getMethod("getPlugin",String.class).invoke(registry,"CompanionUpdater");
      expect(updater!=null,"Updater registered");
      Class<?> type=updater.getClass();
      JSONObject installed=new JSONObject((String)type.getMethod("installed_version").invoke(updater));
      expect(installed.getInt("code")>=102,"Installed version");
      Method url=type.getDeclaredMethod("checkedUrl",String.class);url.setAccessible(true);
      url.invoke(updater,"https://zz.zhangyue.site/weather-companion/latest.json");checks++;
      for(String bad:new String[]{"http://zz.zhangyue.site/weather-companion/latest.json","https://example.com/weather-companion/latest.json","https://zz.zhangyue.site/other/latest.json","https://zz.zhangyue.site/weather-companion/../secret","https://user@zz.zhangyue.site/weather-companion/latest.json"}) rejects(url,updater,bad);
      File apk=new File(getTargetContext().getApplicationInfo().sourceDir);
      Method verify=type.getDeclaredMethod("verify",File.class,JSONObject.class);verify.setAccessible(true);
      JSONObject manifest=new JSONObject().put("bytes",apk.length()+1).put("sha256","0").put("version_code",installed.getInt("code"));
      rejects(verify,updater,apk,manifest);
      manifest.put("bytes",apk.length()); rejects(verify,updater,apk,manifest);
      MessageDigest digest=MessageDigest.getInstance("SHA-256");
      try(InputStream in=new FileInputStream(apk)){byte[] b=new byte[65536];int n;while((n=in.read(b))!=-1)digest.update(b,0,n);}
      StringBuilder hash=new StringBuilder();for(byte b:digest.digest())hash.append(String.format("%02x",b&255));
      manifest.put("sha256",hash.toString());
      rejects(verify,updater,apk,manifest); // authentic same-version APK must not reinstall/downgrade
      if(network) {
        type.getMethod("check_update",String.class).invoke(updater,"https://zz.zhangyue.site/weather-companion/latest.json");
        awaitIdle(type,updater,60000);
        Field mf=type.getDeclaredField("manifest");mf.setAccessible(true);
        JSONObject incoming=(JSONObject)mf.get(updater);
        expect(incoming!=null && incoming.getInt("version_code")>installed.getInt("code"),"Live newer release discovered");
        type.getMethod("download_update").invoke(updater);
        awaitIdle(type,updater,240000);
        Field ready=type.getDeclaredField("readyFile");ready.setAccessible(true);
        File downloaded=(File)ready.get(updater);
        expect(downloaded!=null && downloaded.isFile(),"Live download verified and ready");
        verify.invoke(updater,downloaded,incoming);checks++;
        Class<?> provider=Class.forName("androidx.core.content.FileProvider");
        Object uri=provider.getMethod("getUriForFile",Context.class,String.class,File.class).invoke(null,getTargetContext(),"com.weather.companion.updates",downloaded);
        expect(uri.toString().startsWith("content://com.weather.companion.updates/"),"Installer URI valid");
        result.putString("online","PASS HTTPS manifest, APK download, package/version/signer verification and installer URI");
      }
      result.putString("stream","PASS native OTA: "+checks+" checks; plugin registration, version, URL policy, size, hash and same-version rejection\n");
      finish(Activity.RESULT_OK,result);
    }catch(Throwable error){result.putString("stream","FAIL "+error+"\n");finish(Activity.RESULT_CANCELED,result);}
  }
}
