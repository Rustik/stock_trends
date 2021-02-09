# StockTrends

Evaluates stock trends daily and save it to database.

1. Backend task pulls and aggregates financial data for tickers in CSV file which is downloaded from nasdaq official ftp, evaluates it against several strategies to get the trend, and if trend is found then saves it to database:

`TICKERS_CSV_PATH=priv/otherlisted.txt mix trends_puller.pull`
`TICKERS_CSV_PATH=priv/nasdaqlisted.txt mix trends_puller.pull`


2. Simple UI to browse and sort trends.
3. Specs is in progress.
