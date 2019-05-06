#include "util_calendar_event_mac.h"
//#include "notify/common_notify.h"
#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>
#import <EventKit/EventKitDefines.h>
#import <EventKit/EKTypes.h>
#import <EventKit/EKEventStore.h>

static EKEventStore *eventStore = nil;
static NSDateComponents *oneDayAgoComponents = nil;
static NSDateComponents *threeMonthFromNowComponents = nil;
static QString trEventTitle = "Class";
static QString trEventNotesGroupID = "Group ID";
static QString trEventNotesClassTitle = "Class Title";
static QString trEventNotesClassLocation = "Class Link";

// add Event thread
CalendarAddEventThread::CalendarAddEventThread(QVector<CalendarEventNode> &eventInfoVec, QString calendarName)
    :m_calendarName(calendarName)
{
    // clear eventInfoVec, get the eventInfoVec's details
    m_vecCalendarEventNode.swap(eventInfoVec);
}

void CalendarAddEventThread::run()
{
    // loop Handle these events
    for (auto iVec : m_vecCalendarEventNode) {
        Util::CalendarEventMac::addEvent(iVec ,m_calendarName.toNSString());
    }
}

namespace Util {

    bool CalendarEventMac::getCalendarPermission()
    {
        // [requestAccessToEntityType] ask for the permission of calendar
        bool hasPermision = false;
        EKAuthorizationStatus EKstatus = [EKEventStore  authorizationStatusForEntityType:EKEntityTypeEvent];
        switch (EKstatus) {
          case EKAuthorizationStatusAuthorized:
              NSLog(@"Authorized");
              hasPermision = true;
              break;
          case EKAuthorizationStatusDenied:
              NSLog(@"Denied'");
              hasPermision = false;
              break;
          case EKAuthorizationStatusNotDetermined:
              NSLog(@"not Determined");
              hasPermision = false;
              break;
          case EKAuthorizationStatusRestricted:
              NSLog(@"Restricted");
              hasPermision = false;
              break;
          default:
              break;
        }

        return hasPermision;
    }

    bool CalendarEventMac::hasCalendar(QString calendarName)
    {
        eventStore = [[EKEventStore alloc] init];
        if (eventStore == nil) {
            return false;
        }

        oneDayAgoComponents = [[NSDateComponents alloc] init];
        threeMonthFromNowComponents = [[NSDateComponents alloc] init];
        if (oneDayAgoComponents == nil || threeMonthFromNowComponents == nil) {
            return false;
        }

        // calendar name:  -nickName
        NSString *strCalendarName = calendarName.toNSString();

        bool bFindResult = false;

        for (EKCalendar *ekcalendar_check in [eventStore calendarsForEntityType:EKEntityTypeEvent]) {
            if ([ekcalendar_check.title isEqualToString:strCalendarName]) {
                bFindResult = true;
                break;
            }
        }

        return bFindResult;
    }

    bool CalendarEventMac::createCalendar(QString calendarName)
    {
        if (eventStore == nil) {
            return false;
        }

        // calendar name:  -nickName
        NSString *strCalendarName = calendarName.toNSString();

        bool bFindResult = false;
        for (EKCalendar *ekcalendar_check in [eventStore calendarsForEntityType:EKEntityTypeEvent]) {
            if ([ekcalendar_check.title isEqualToString:strCalendarName]) {
                bFindResult = true;
                break;
            }
        }

        if (!bFindResult) {
            // if the calendar not create, we create one
            [eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{

                NotifyParam param;
                param.type = eNotify_MacSyncCalendarAuthority;

                if (error) {
                    // maybe error occur, display it
                    NSLog(@"error=%@", error);
                    param.param1 = 0;
                } else if(!granted) {
                    // access denyed
                    NSLog(@"deny the permission");
                    param.param1 = 0;
                } else {
                    // access granted
                    NSLog(@"agree the permission");

                    // find the iCloud-source
                    NSArray *csArray = [eventStore calendarsForEntityType:EKEntityTypeEvent];
                    EKSource *iCloudSource = nil;
                    for (int i = 0; i < csArray.count; i++) {
                        EKCalendar *ekcalendar_tmp = [csArray objectAtIndex:i];
                        if ([ekcalendar_tmp.source.title isEqualToString:@"iCloud"]) {
                            iCloudSource = ekcalendar_tmp.source;
                            break;
                        }
                    }

                    // set the calendar's datailed information
                    EKCalendar *ekcalendar_default = [eventStore defaultCalendarForNewEvents];
                    EKCalendar *ekcalendar_new = [EKCalendar calendarForEntityType:EKEntityTypeEvent eventStore:eventStore];
                    ekcalendar_new.title = strCalendarName;
                    ekcalendar_new.color = [NSColor colorWithRed:42/255.0f green:131/255.0f blue:243/255.0f alpha:1.0f];
                    ekcalendar_new.source = iCloudSource?:ekcalendar_default.source;

                    // save the new calendar, commit it to the local-system-database
                    [eventStore saveCalendar:ekcalendar_new commit:YES error:NULL];

                    if (error) {
                        NSLog(@"error=%@", error);
                        param.param1 = 0;
                    } else {
                        param.param1 = 1;
                    }
                }
                //CommonNotify::getInstance()->pushNotify(&param, true);
             });
            }];
        } else {
            // if calendar already create, return true
            return true;
        }

        return true;
    }

    bool CalendarEventMac::prepareTranslation(QString _trEventTitle, QString _trEventNotesGroupID, QString _trEventNotesClassTitle, QString _trEventNotesClassLocation)
    {
        trEventTitle                = _trEventTitle;
        trEventNotesGroupID         = _trEventNotesGroupID;
        trEventNotesClassTitle      = _trEventNotesClassTitle;
        trEventNotesClassLocation   = _trEventNotesClassLocation;

        return true;
    }

    NSString* CalendarEventMac::parseContentIdFormNotes(NSString *notes)
    {
        NSRange range1 = [notes rangeOfString:@"videoId%22%3A%22" options:NSRegularExpressionSearch];
        NSRange range2 = [notes rangeOfString:@"%22%7D&pageoption" options:NSRegularExpressionSearch];
        NSUInteger location = range1.location + range1.length;
        NSUInteger length = range2.location - location;

        // in case of crash
        if (length <= 0) {
            return nil;
        }

        NSString *parseCode = [notes substringWithRange:NSMakeRange(location, length)];
        return parseCode;
    }

    bool CalendarEventMac::removeEvent(CalendarEventNode eventInfo, NSString *calendarName)
    {
        if (eventStore == nil) {
            return false;
        }

        NSCalendar *calendar = [NSCalendar currentCalendar];

        if (oneDayAgoComponents == nil || threeMonthFromNowComponents == nil) {
            return false;
        }

        // get the date of yesterday
        oneDayAgoComponents.day = -1;
        NSDate *oneDayAgo = [calendar dateByAddingComponents:oneDayAgoComponents toDate:[NSDate date] options:0];

        // get the date of 3-month-later
        threeMonthFromNowComponents.month = 3;
        NSDate *threeMonthFromNow = [calendar dateByAddingComponents:threeMonthFromNowComponents toDate:[NSDate date] options:0];

        for (EKCalendar *ekcalendar_check in [eventStore calendarsForEntityType:EKEntityTypeEvent]) {
            if ([ekcalendar_check.title isEqualToString:calendarName]) {
                NSArray *csArray = [eventStore calendarsForEntityType:EKEntityTypeEvent];
                NSPredicate *predicate = [eventStore predicateForEventsWithStartDate:oneDayAgo endDate:threeMonthFromNow calendars:nil];

                if(predicate == nil) {
                    NSLog(@"predicate is null");
                }

                // loop delete the repeat-event
                [eventStore enumerateEventsMatchingPredicate:predicate usingBlock:^(EKEvent * _Nonnull event, BOOL * _Nonnull stop) {
                    NSString *eventID_nsstring = QString::number(eventInfo.eventID, 10).toNSString();
                    NSString *contentId = parseContentIdFormNotes(event.notes);

                    if ([eventID_nsstring isEqualToString:contentId]) {
                        NSError *error;
                        [eventStore removeEvent:event span:EKSpanThisEvent commit:YES error:&error];

                        if (error) {
                            NSLog(@"error=%@", error);
                        }
                    }
                }];

                break;
            }
        }
        return true;
    }

    bool CalendarEventMac::addEvent(CalendarEventNode eventInfo, NSString *calendarName)
    {
        if (eventStore == nil) {
            return false;
        }

        EKEvent *event = [EKEvent eventWithEventStore:eventStore];
        if (event == nil) {
            return false;
        }

        // handle the repeat-event [if exist, remove it]
        removeEvent(eventInfo, calendarName);

        // event be deleted by manual, so we remove it and no need to add it
        if (eventInfo.eventDeleteStatus) {
            return true;
        }

        // in case of add event error, find the calendar
        bool bFindResult = false;
        for (EKCalendar *ekcalendar_check in [eventStore calendarsForEntityType:EKEntityTypeEvent]) {
            if ([ekcalendar_check.title isEqualToString:calendarName]) {
                bFindResult = true;
                [event setCalendar:ekcalendar_check];
                break;
            }
        }

        if (!bFindResult) {
            // if not find the calendar which named: [-nickname], do not add event
            return false;
        }

        // title
        event.title = [NSString stringWithFormat:@"%@%@", trEventTitle.toNSString(), eventInfo.eventTitle.toNSString()];

        // time
        event.startDate = [NSDate dateWithTimeIntervalSince1970:(double)eventInfo.eventStartTime];
        event.endDate = [NSDate dateWithTimeIntervalSince1970:(double)eventInfo.eventEndTime];

        // add the reminder
        event.allDay = NO;
        // remind the user before the class 15-minutes
        [event addAlarm:[EKAlarm alarmWithRelativeOffset:60.0f * -15.0f]];

        // event.url
        NSString *eventID_nsstring = QString::number(eventInfo.eventID, 10).toNSString();
//        NSString *address = @"ctim://sendmsg?type=content&id=";
//        address = [NSString stringWithFormat:@"%@%@", address, eventID_nsstring];
        NSString *address = @"https://www.cctalk.com/m/wechatapp?pagename=program&pageparam=%7B%22videoId%22%3A%22";
        NSString *addressParams = @"%22%7D&pageoption=%7B%22withUniversalLink%22%3A%20false%2C%22withDeepLink%22%3A%20true%7D";
        address = [NSString stringWithFormat:@"%@%@%@", address, eventID_nsstring, addressParams];

        // notes
        NSString *eventGroupID_nsstring = QString::number(eventInfo.eventGroupID, 10).toNSString();
        event.notes = [NSString stringWithFormat:@"%@: %@\n%@: %@\n%@: %@", trEventNotesGroupID.toNSString(),
                                                                            eventGroupID_nsstring,
                                                                            trEventNotesClassTitle.toNSString(),
                                                                            eventInfo.eventTitle.toNSString(),
                                                                            trEventNotesClassLocation.toNSString(),
                                                                            address];

        NSError *error;
        [eventStore saveEvent:event span:EKSpanThisEvent commit:YES error:&error];

        if (error) {
            NSLog(@"error=%@", error);
            return false;
        }
    }
}
