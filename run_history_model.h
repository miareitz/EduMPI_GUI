#ifndef RUN_HISTORY_MODEL_H
#define RUN_HISTORY_MODEL_H

#include <QSqlQueryModel>

class RunHistoryModel : public QSqlQueryModel
{
    Q_OBJECT
public:
    enum Roles {
        TimeRole = Qt::UserRole + 1,
        RankRole,
        FunctionRole,
        PartnerRole,
        SendRole,
        RecvRole,
        TypeRole,
        DurationRole,
        DisplacementRole,
        WindowRole
    };

    explicit RunHistoryModel(QObject *parent = nullptr);

    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setConnectionName(const QString &name);

    Q_INVOKABLE int count() const { return rowCount(); }

    Q_INVOKABLE void setRunQuery(int slurmId, bool hideSelf);

    Q_INVOKABLE void sortBy(int column, bool ascending);

private:
    QString orderByClause() const;

    QString m_connectionName;
    int m_slurmId = -1;
    bool m_hideSelf = true;
    int m_sortColumn = 0;
    bool m_sortAscending = true;
};

#endif // RUN_HISTORY_MODEL_H
