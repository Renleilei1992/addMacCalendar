/*================================================================
*   Copyright (C) 2019 Renleilei. All rights reserved.
*   
*   文件名称：util_calendar_event_mac.h
*   创 建 者：Renleilei (renleilei1992@foxmail.com)
*   创建日期：2019年02月06日
*   描    述：工具类-添加事件到MacOS的日历中(与iPhone日历同步)
*   版    本: Version 1.00
================================================================*/
#pragma once
#ifndef UTIL_CALENDAR_EVENT_MAC_H
#define UTIL_CALENDAR_EVENT_MAC_H
#include <QString>
#include <QThread>
#include <QVector>

struct CalendarEventNode
{
    quint64 eventID             = 0;
    QString eventTitle          = "";
    quint64 eventStartTime      = 0;
    quint64 eventEndTime        = 0;
    quint32 eventType           = 0;
    quint32 eventDeleteStatus   = 0;
};

class CalendarAddEventThread : public QThread
{
public:
    CalendarAddEventThread(QVector<CalendarEventNode> &eventInfoVec, QString calendarName);
protected:
    void run();

private:
    QVector<CalendarEventNode> m_vecCalendarEventNode;
    QString m_calendarName = "";
};

namespace Util {
    namespace CalendarEventMac
    {
        bool getCalendarPermission();
        bool hasCalendar(QString calendarName);
        bool createCalendar(QString calendarName);
        bool prepareTranslation(QString _trEventTitle,
                                                          QString _trEventNotesGroupID,
                                                          QString _trEventNotesClassTitle,
                                                          QString _trEventNotesClassLocation);

        // private
        NSString* parseContentIdFormNotes(NSString *notes);
        bool removeEvent(CalendarEventNode eventInfo, NSString *calendarName);
        bool addEvent(CalendarEventNode eventInfo, NSString *calendarName);

    }
}


#endif // UTIL_CALENDAR_EVENT_MAC_H
