#import <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <math.h>

typedef struct {float x,y;} Vector2;
typedef struct {Vector2 position,velocity;} Motion;
typedef struct {
    int32_t frame;double time;int32_t path,state,identifier,hand;
    Motion normalized;float size;int32_t reserved;float angle,major,minor;
    Motion absolute;int32_t reserved2,reserved3;float density;
} Contact;
_Static_assert(sizeof(Contact)==96,"Multitouch contact ABI mismatch");
typedef struct {float x,y;int32_t id;} LPTouchPoint;
typedef void *Device;
typedef void (*FrameCallback)(Device,const Contact *,int,double,int);
extern int lp_gesture_frame(uintptr_t,const LPTouchPoint *,size_t,double);
extern void lp_gesture_reset(void);
static void *library;
static CFArrayRef devices;
static CFArrayRef (*createList)(void);
static void (*registerFrame)(Device,FrameCallback);
static void (*unregisterFrame)(Device,FrameCallback);
static void (*startDevice)(Device,int);
static void (*stopDevice)(Device);
static bool (*opaqueSurface)(Device);
static bool (*running)(Device);
static void (*actionHandler)(int);
static atomic_bool enabled=false;
static atomic_int contacts=0;
static const char *status="未启用";
static bool load(void){
    if(library)return createList&&registerFrame&&unregisterFrame&&startDevice&&stopDevice;
    library=dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",RTLD_LOCAL|RTLD_NOW);
    if(!library){status="此系统没有可用的多点触控接口";return false;}
    createList=dlsym(library,"MTDeviceCreateList");registerFrame=dlsym(library,"MTRegisterContactFrameCallback");
    unregisterFrame=dlsym(library,"MTUnregisterContactFrameCallback");startDevice=dlsym(library,"MTDeviceStart");stopDevice=dlsym(library,"MTDeviceStop");
    opaqueSurface=dlsym(library,"MTDeviceIsOpaqueSurface");running=dlsym(library,"MTDeviceIsRunning");
    if(!createList||!registerFrame||!unregisterFrame||!startDevice||!stopDevice){status="此系统的触控接口版本不兼容";return false;}return true;
}
static void frame(Device device,const Contact *data,int count,double time,int index){
    (void)index;
    if(!atomic_load(&enabled))return;
    if(count<0||count>16||(count>0&&!data))return;
    LPTouchPoint points[16];size_t active=0;
    for(int i=0;i<count;i++)if(data[i].state==3||data[i].state==4){
        points[active++]=(LPTouchPoint){data[i].normalized.position.x,data[i].normalized.position.y,data[i].identifier};
    }
    atomic_store(&contacts,(int)active);
    int action=lp_gesture_frame((uintptr_t)device,points,active,time);
    if(action&&atomic_load(&enabled)&&actionHandler)actionHandler(action);
}
void lp_gesture_stop(void){
    atomic_store(&enabled,false);
    if(devices){for(CFIndex i=0;i<CFArrayGetCount(devices);i++){Device d=(Device)CFArrayGetValueAtIndex(devices,i);stopDevice(d);if(unregisterFrame)unregisterFrame(d,frame);}CFRelease(devices);devices=NULL;}
    atomic_store(&contacts,0);lp_gesture_reset();status="未启用";
}
bool lp_gesture_start(void (*handler)(int)){
    lp_gesture_stop();if(!load())return false;
    CFArrayRef list=createList();if(!list){status="未检测到触控板";return false;}
    CFMutableArrayRef selected=CFArrayCreateMutable(NULL,0,&kCFTypeArrayCallBacks);
    for(CFIndex i=0;i<CFArrayGetCount(list);i++){Device d=(Device)CFArrayGetValueAtIndex(list,i);if(!opaqueSurface||opaqueSurface(d))CFArrayAppendValue(selected,d);}
    CFRelease(list);if(CFArrayGetCount(selected)==0){CFRelease(selected);status="未检测到兼容的触控板";return false;}
    devices=selected;actionHandler=handler;atomic_store(&enabled,true);
    int started=0;
    for(CFIndex i=0;i<CFArrayGetCount(devices);i++){Device d=(Device)CFArrayGetValueAtIndex(devices,i);registerFrame(d,frame);startDevice(d,0);if(!running||running(d))started++;}
    if(!started){lp_gesture_stop();status="触控板未能启动；请检查系统输入监控权限";return false;}
    status="已启用：五指收拢打开、展开关闭";return true;
}
bool lp_gesture_enabled(void){return atomic_load(&enabled);}
int lp_gesture_contacts(void){return atomic_load(&contacts);}
const char *lp_gesture_status(void){return status;}
int lp_gesture_probe(void){
    if(!load())return -1;
    CFArrayRef list=createList();if(!list)return 0;int found=0;
    for(CFIndex i=0;i<CFArrayGetCount(list);i++)if(!opaqueSurface||opaqueSurface((Device)CFArrayGetValueAtIndex(list,i)))found++;
    CFRelease(list);return found;
}
