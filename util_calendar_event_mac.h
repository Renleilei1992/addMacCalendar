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
    quint32 eventGroupID        = 0;
    QString eventGroupName      = "";
    quint32 eventVideoStatus    = 0;
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
