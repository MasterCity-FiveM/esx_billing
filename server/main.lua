ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterServerEvent('esx_billing:sendBill')
AddEventHandler('esx_billing:sendBill', function(playerId, sharedAccountName, label, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	local xTarget = ESX.GetPlayerFromId(playerId)
	if xPlayer.job.name == "police" or xPlayer.getGroup() ~= 'user' then
		return
	end
	
	amount = ESX.Math.Round(amount)

	if amount > 0 and xTarget then
		TriggerEvent('esx_addonaccount:getSharedAccount', sharedAccountName, function(account)
			if account then
				MySQL.Async.execute('INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (@identifier, @sender, @target_type, @target, @label, @amount)', {
					['@identifier'] = xTarget.identifier,
					['@sender'] = xPlayer.identifier,
					['@target_type'] = 'society',
					['@target'] = sharedAccountName,
					['@label'] = label,
					['@amount'] = amount
				}, function(rowsChanged)
					TriggerClientEvent("pNotify:SendNotification", source, { text = "شما یک جریمه دریافت کردید.", type = "error", timeout = 4000, layout = "bottomCenter"})
				end)
			else
				MySQL.Async.execute('INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (@identifier, @sender, @target_type, @target, @label, @amount)', {
					['@identifier'] = xTarget.identifier,
					['@sender'] = xPlayer.identifier,
					['@target_type'] = 'player',
					['@target'] = xPlayer.identifier,
					['@label'] = label,
					['@amount'] = amount
				}, function(rowsChanged)
					TriggerClientEvent("pNotify:SendNotification", source, { text = "شما یک جریمه دریافت کردید.", type = "error", timeout = 4000, layout = "bottomCenter"})
				end)
			end
		end)
	end
end)

ESX.RegisterServerCallback('esx_billing:getBills', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.fetchAll('SELECT amount, id, label FROM billing WHERE identifier = @identifier limit 10', {
		['@identifier'] = xPlayer.identifier
	}, function(result)
		cb(result)
	end)
end)

ESX.RegisterServerCallback('esx_billing:getTargetBills', function(source, cb, target)
	local xPlayer = ESX.GetPlayerFromId(target)

	if xPlayer then
		MySQL.Async.fetchAll('SELECT amount, id, label FROM billing WHERE identifier = @identifier limit 10', {
			['@identifier'] = xPlayer.identifier
		}, function(result)
			cb(result)
		end)
	else
		cb({})
	end
end)

ESX.RegisterServerCallback('esx_billing:payBill', function(source, cb, billId)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.fetchAll('SELECT sender, target_type, target, amount FROM billing WHERE id = @id', {
		['@id'] = billId
	}, function(result)
		if result[1] then
			local amount = result[1].amount
			local xTarget = ESX.GetPlayerFromIdentifier(result[1].sender)

			if result[1].target_type == 'player' then
				if xTarget then
					if xPlayer.getMoney() >= amount then
						MySQL.Async.execute('DELETE FROM billing WHERE id = @id', {
							['@id'] = billId
						}, function(rowsChanged)
							if rowsChanged == 1 then
								xPlayer.removeMoney(amount)
								xTarget.addMoney(amount)

								TriggerClientEvent("pNotify:SendNotification", xTarget.source, { text = "جریمه پرداخت شد، شما مبلغ " .. ESX.Math.GroupDigits(amount) .. "$ دریافت کردید.", type = "error", timeout = 4000, layout = "bottomCenter"})
								TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = "جریمه پرداخت شد.", type = "error", timeout = 4000, layout = "bottomCenter"})
							end

							cb()
						end)
					elseif xPlayer.getAccount('bank').money >= amount then
						MySQL.Async.execute('DELETE FROM billing WHERE id = @id', {
							['@id'] = billId
						}, function(rowsChanged)
							if rowsChanged == 1 then
								xPlayer.removeAccountMoney('bank', amount)
								xTarget.addAccountMoney('bank', amount)

								TriggerClientEvent("pNotify:SendNotification", xTarget.source, { text = "جریمه پرداخت شد، شما مبلغ " .. ESX.Math.GroupDigits(amount) .. "$ دریافت کردید.", type = "error", timeout = 4000, layout = "bottomCenter"})
								TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = "جریمه پرداخت شد.", type = "error", timeout = 4000, layout = "bottomCenter"})
							end

							cb()
						end)
					else
						TriggerClientEvent("pNotify:SendNotification", xTarget.source, { text = "شهروند پول کافی برای پرداخت جریمه را ندارد.", type = "error", timeout = 4000, layout = "bottomCenter"})
						TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = "شما پول کافی جهت پرداخت جریمه را ندارید.", type = "error", timeout = 4000, layout = "bottomCenter"})
						cb()
					end
				else
					xPlayer.showNotification(_U('player_not_online'))
					cb()
				end
			else
				TriggerEvent('esx_addonaccount:getSharedAccount', result[1].target, function(account)
					if xPlayer.getMoney() >= amount then
						MySQL.Async.execute('DELETE FROM billing WHERE id = @id', {
							['@id'] = billId
						}, function(rowsChanged)
							if rowsChanged == 1 then
								xPlayer.removeMoney(amount)
								account.addMoney(amount)

								TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = "جریمه پرداخت شد.", type = "error", timeout = 4000, layout = "bottomCenter"})
								if xTarget then
									TriggerClientEvent("pNotify:SendNotification", xTarget.source, { text = "جریمه پرداخت شد، شما مبلغ " .. ESX.Math.GroupDigits(amount) .. "$ دریافت کردید.", type = "error", timeout = 4000, layout = "bottomCenter"})
								end
							end

							cb()
						end)
					elseif xPlayer.getAccount('bank').money >= amount then
						MySQL.Async.execute('DELETE FROM billing WHERE id = @id', {
							['@id'] = billId
						}, function(rowsChanged)
							if rowsChanged == 1 then
								xPlayer.removeAccountMoney('bank', amount)
								account.addMoney(amount)
								TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = "جریمه پرداخت شد.", type = "error", timeout = 4000, layout = "bottomCenter"})

								if xTarget then
									riggerClientEvent("pNotify:SendNotification", xTarget.source, { text = "جریمه پرداخت شد، شما مبلغ " .. ESX.Math.GroupDigits(amount) .. "$ دریافت کردید.", type = "error", timeout = 4000, layout = "bottomCenter"})
								end
							end

							cb()
						end)
					else
						if xTarget then
							TriggerClientEvent("pNotify:SendNotification", xTarget.source, { text = "شهروند پول کافی برای پرداخت جریمه را ندارد.", type = "error", timeout = 4000, layout = "bottomCenter"})
						end

						TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = "شما پول کافی جهت پرداخت جریمه را ندارید.", type = "error", timeout = 4000, layout = "bottomCenter"})
						cb()
					end
				end)
			end
		end
	end)
end)
