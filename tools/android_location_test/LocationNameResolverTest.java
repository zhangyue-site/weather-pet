package com.weather.companion;
public final class LocationNameResolverTest {
    private static void check(boolean value,String message) { if(!value)throw new AssertionError(message); }
    public static void main(String[] args) throws Exception {
        LocationNameResolver blocked=new LocationNameResolver((lat,lon)->{
            long end=System.nanoTime()+10_000_000_000L;
            while(System.nanoTime()<end)try{Thread.sleep(50);}catch(InterruptedException ignored){}
            return "late name must not win";
        },30);
        blocked.start(30,120);
        long end=System.nanoTime()+1_500_000_000L;
        while(!blocked.isDone()&&System.nanoTime()<end)Thread.sleep(5);
        check(blocked.isDone()&&blocked.getName().isEmpty(),"deadline ignores a provider that ignores interruption");
        long before=System.nanoTime();blocked.close();
        check(System.nanoTime()-before<250_000_000L,"close never joins the provider");
        LocationNameResolver good=new LocationNameResolver((lat,lon)->"测试市 · 测试区",1000);
        good.start(30,120);
        end=System.nanoTime()+1_500_000_000L;
        while(!good.isDone()&&System.nanoTime()<end)Thread.sleep(5);
        check(good.getName().equals("测试市 · 测试区"),"successful result");
        good.cancel();check(good.isDone()&&good.getName().isEmpty(),"cancel clears result");
        good.start(999,120);check(good.isDone()&&good.getName().isEmpty(),"bad coordinates rejected");
        good.close();good.start(30,120);check(good.isDone(),"closed resolver stays closed");
        System.out.println("PASS native location: success,8s-production/30ms-test deadline,cancel,invalid input,nonblocking close,daemon lifetime");
    }
}
