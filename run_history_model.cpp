#include "run_history_model.h"

#include <QSqlDatabase>
#include <QSqlError>
#include <QDebug>
#include <QDateTime>

RunHistoryModel::RunHistoryModel(QObject *parent) : QSqlQueryModel(parent) {}

void RunHistoryModel::setConnectionName(const QString &name)
{
    m_connectionName = name;
}

void RunHistoryModel::setRunQuery(int slurmId, bool hideSelf)
{
    m_slurmId = slurmId;
    m_hideSelf = hideSelf;

    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    if (!db.isOpen()) {
        qWarning() << "RunHistoryModel: database not open";
        return;
    }
    QString q = QString("SELECT time_start, processrank, \"function\", partnerrank, senddatasize, recvdatasize, "
                        "communicationtype, time_diff, target_disp, win_addr "
                        "FROM edumpi_running_data WHERE edumpi_run_id = %1").arg(slurmId);
    if (hideSelf) {
        q += " AND partnerrank != processrank";
    }
    q += " ORDER BY " + orderByClause();
    setQuery(q, db);
    if (lastError().isValid()) {
        qWarning() << "RunHistoryModel query error:" << lastError().text();
    }
}

QString RunHistoryModel::orderByClause() const
{
    static const char *const columns[] = {
        "time_start", "processrank", "\"function\"", "partnerrank",
        "senddatasize", "recvdatasize", "communicationtype",
        "time_diff", "target_disp", "win_addr"
    };
    const int columnCount = static_cast<int>(sizeof(columns) / sizeof(columns[0]));
    QString col = (m_sortColumn >= 0 && m_sortColumn < columnCount)
                      ? QString::fromLatin1(columns[m_sortColumn])
                      : QStringLiteral("time_start");
    return col + (m_sortAscending ? QStringLiteral(" ASC") : QStringLiteral(" DESC"));
}

void RunHistoryModel::sortBy(int column, bool ascending)
{
    m_sortColumn = column;
    m_sortAscending = ascending;
    setRunQuery(m_slurmId, m_hideSelf);
}

QVariant RunHistoryModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid()) {
        return QVariant();
    }
    int col = -1;
    switch (role) {
        case TimeRole: col = 0; break;
        case RankRole: col = 1; break;
        case FunctionRole: col = 2; break;
        case PartnerRole: col = 3; break;
        case SendRole: col = 4; break;
        case RecvRole: col = 5; break;
        case TypeRole: col = 6; break;
        case DurationRole: col = 7; break;
        case DisplacementRole: col = 8; break;
        case WindowRole: col = 9; break;
        default:
            return QSqlQueryModel::data(index, role);
    }
    QVariant raw = QSqlQueryModel::data(QSqlQueryModel::index(index.row(), col), Qt::DisplayRole);
    if (role == TimeRole) {
        return raw.toDateTime().toString("HH:mm:ss.zzz");
    }
    if (role == DurationRole) {
        double sec = raw.toDouble();
        if (sec >= 1.0) return QString::number(sec, 'f', 3) + " s";
        if (sec >= 0.001) return QString::number(sec * 1000.0, 'f', 2) + " ms";
        return QString::number(sec * 1000000.0, 'f', 1) + " µs";
    }
    if (role == WindowRole) {
        qlonglong a = raw.toLongLong();
        if (a == 0) return QString();
        return QString("0x%1").arg(a, 0, 16);
    }
    return raw;
}

QHash<int, QByteArray> RunHistoryModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[TimeRole] = "time";
    roles[RankRole] = "rank";
    roles[FunctionRole] = "func";
    roles[PartnerRole] = "partner";
    roles[SendRole] = "send";
    roles[RecvRole] = "recv";
    roles[TypeRole] = "type";
    roles[DurationRole] = "duration";
    roles[DisplacementRole] = "displacement";
    roles[WindowRole] = "window";
    return roles;
}
