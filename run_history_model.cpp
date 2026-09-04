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

void RunHistoryModel::setRunQuery(int slurmId, bool hideSelf, int winIndex)
{
    m_slurmId = slurmId;
    m_hideSelf = hideSelf;
    m_winIndex = winIndex;

    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    if (!db.isOpen()) {
        qWarning() << "RunHistoryModel: database not open";
        return;
    }
    QString q = QString("SELECT time_start, processrank, \"function\", partnerrank, senddatasize, recvdatasize, "
                        "communicationtype, time_diff, target_disp, win_base, win_index, callsites "
                        "FROM edumpi_running_data WHERE edumpi_run_id = %1").arg(slurmId);
    if (hideSelf) {
        q += " AND partnerrank != processrank";
    }
    if (winIndex >= 0) {
        q += QString(" AND win_index = %1").arg(winIndex);
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
        "time_diff", "target_disp", "win_base", "win_index", "callsites"
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
    setRunQuery(m_slurmId, m_hideSelf, m_winIndex);
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
        case WinIndexRole: col = 10; break;
        case CallsitesRole: col = 11; break;
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
    if (role == WinIndexRole) {
        // win_index 0 = no window (index 0 is reserved for MPI_WIN_NULL;
        // p2p/collective rows are recorded with 0). Old runs have NULL -> 0.
        int wi = raw.toInt();
        if (wi == 0) return QString();
        return QString::number(wi);
    }
    if (role == CallsitesRole) {
        // 24-byte BYTEA = 3 big-endian 64-bit return addresses.
        QByteArray b = raw.toByteArray();
        if (b.size() != 24) return QString();
        const unsigned char *d = reinterpret_cast<const unsigned char *>(b.constData());
        auto read64 = [&](int off) {
            quint64 a = 0;
            for (int i = 0; i < 8; i++) a = (a << 8) | d[off + i];
            return a;
        };
        QString out;
        for (int i = 0; i < 3; i++) {
            quint64 a = read64(i * 8);
            if (a == 0) break;
            if (!out.isEmpty()) out += QLatin1String(" | ");
            out += QString("0x%1").arg(a, 0, 16);
        }
        return out;
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
    roles[WinIndexRole] = "winindex";
    roles[CallsitesRole] = "callsites";
    return roles;
}
