json.html render partial: 'pages/extended_panel.html.erb', :locals => {:data => jobstatusdata, :page=>'index'}
json.status jobstatusdata.status
