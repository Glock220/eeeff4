---Emperor by Zv7i
---Converted to realchar by typicalusername
---Converted from Lua sandbox to regular script by StringExpected/Cxrn_45






local function DecodeUnion(Values,Flags,Parse,data)
	local m = Instance.new("Folder")
	m.Name = "UnionCache ["..tostring(math.random(1,9999)).."]"
	m.Archivable = false
	m.Parent = game:GetService("ServerStorage")
	local Union,Subtract = {},{}
	if not data then
		data = Parse('B')
	end
	local ByteLength = (data % 4) + 1
	local Length = Parse('I'..ByteLength)
	local ValueFMT = ('I'..Flags[1])
	for i = 1,Length do
		local data = Parse('B')
		local part
		local isNegate = bit32.band(data,0b10000000) > 0
		local isUnion =  bit32.band(data,0b01000000) > 0
		if isUnion then
			part = DecodeUnion(Values,Flags,Parse,data)
		else
			local isMesh = data % 2 == 1
			local ClassName = Values[Parse(ValueFMT)]
			part = Instance.new(ClassName)
			part.Size = Values[Parse(ValueFMT)]
			part.Position = Values[Parse(ValueFMT)]
			part.Orientation = Values[Parse(ValueFMT)]
			if isMesh then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Values[Parse(ValueFMT)]
				mesh.Scale = Values[Parse(ValueFMT)]
				mesh.Offset = Values[Parse(ValueFMT)]
				mesh.Parent = part
			end
		end
		part.Parent = m
		table.insert(isNegate and Subtract or Union,part)
	end
	local first = table.remove(Union,1)
	if #Union>0 then
		first = first:UnionAsync(Union)
	end
	if #Subtract>0 then
		first = first:SubtractAsync(Subtract)
	end
	m:Destroy()
	return first
end

local function Decode(str)
	local StringLength = #str

	-- Base64 decoding
	do
		local decoder = {}
		for b64code, char in pairs(('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='):split('')) do
			decoder[char:byte()] = b64code-1
		end
		local n = StringLength
		local t,k = table.create(math.floor(n/4)+1),1
		local padding = str:sub(-2) == '==' and 2 or str:sub(-1) == '=' and 1 or 0
		for i = 1, padding > 0 and n-4 or n, 4 do
			local a, b, c, d = str:byte(i,i+3)
			local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
			t[k] = string.char(bit32.extract(v,16,8),bit32.extract(v,8,8),bit32.extract(v,0,8))
			k = k + 1
		end
		if padding == 1 then
			local a, b, c = str:byte(n-3,n-1)
			local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40
			t[k] = string.char(bit32.extract(v,16,8),bit32.extract(v,8,8))
		elseif padding == 2 then
			local a, b = str:byte(n-3,n-2)
			local v = decoder[a]*0x40000 + decoder[b]*0x1000
			t[k] = string.char(bit32.extract(v,16,8))
		end
		str = table.concat(t)
	end

	local Position = 1
	local function Parse(fmt)
		local Values = {string.unpack(fmt,str,Position)}
		Position = table.remove(Values)
		return table.unpack(Values)
	end

	local Settings = Parse('B')
	local Flags = Parse('B')
	Flags = {
		--[[ValueIndexByteLength]] bit32.extract(Flags,6,2)+1,
		--[[InstanceIndexByteLength]] bit32.extract(Flags,4,2)+1,
		--[[ConnectionsIndexByteLength]] bit32.extract(Flags,2,2)+1,
		--[[MaxPropertiesLengthByteLength]] bit32.extract(Flags,0,2)+1,
		--[[Use Double instead of Float]] bit32.band(Settings,0b1) > 0
	}

	local ValueFMT = ('I'..Flags[1])
	local InstanceFMT = ('I'..Flags[2])
	local ConnectionFMT = ('I'..Flags[3])
	local PropertyLengthFMT = ('I'..Flags[4])

	local ValuesLength = Parse(ValueFMT)
	local Values = table.create(ValuesLength)
	local CFrameIndexes = {}

	local ValueDecoders = {
		--!!Start
		[1] = function(Modifier)
			return Parse('s'..Modifier)
		end,
		--!!Split
		[2] = function(Modifier)
			return Modifier ~= 0
		end,
		--!!Split
		[3] = function()
			return Parse('d')
		end,
		--!!Split
		[4] = function(_,Index)
			table.insert(CFrameIndexes,{Index,Parse(('I'..Flags[1]):rep(3))})
		end,
		--!!Split
		[5] = {CFrame.new,Flags[5] and 'dddddddddddd' or 'ffffffffffff'},
		--!!Split
		[6] = {Color3.fromRGB,'BBB'},
		--!!Split
		[7] = {BrickColor.new,'I2'},
		--!!Split
		[8] = function(Modifier)
			local len = Parse('I'..Modifier)
			local kpts = table.create(len)
			for i = 1,len do
				kpts[i] = ColorSequenceKeypoint.new(Parse('f'),Color3.fromRGB(Parse('BBB')))
			end
			return ColorSequence.new(kpts)
		end,
		--!!Split
		[9] = function(Modifier)
			local len = Parse('I'..Modifier)
			local kpts = table.create(len)
			for i = 1,len do
				kpts[i] = NumberSequenceKeypoint.new(Parse(Flags[5] and 'ddd' or 'fff'))
			end
			return NumberSequence.new(kpts)
		end,
		--!!Split
		[10] = {Vector3.new,Flags[5] and 'ddd' or 'fff'},
		--!!Split
		[11] = {Vector2.new,Flags[5] and 'dd' or 'ff'},
		--!!Split
		[12] = {UDim2.new,Flags[5] and 'di2di2' or 'fi2fi2'},
		--!!Split
		[13] = {Rect.new,Flags[5] and 'dddd' or 'ffff'},
		--!!Split
		[14] = function()
			local flags = Parse('B')
			local ids = {"Top","Bottom","Left","Right","Front","Back"}
			local t = {}
			for i = 0,5 do
				if bit32.extract(flags,i,1)==1 then
					table.insert(t,Enum.NormalId[ids[i+1]])
				end
			end
			return Axes.new(unpack(t))
		end,
		--!!Split
		[15] = function()
			local flags = Parse('B')
			local ids = {"Top","Bottom","Left","Right","Front","Back"}
			local t = {}
			for i = 0,5 do
				if bit32.extract(flags,i,1)==1 then
					table.insert(t,Enum.NormalId[ids[i+1]])
				end
			end
			return Faces.new(unpack(t))
		end,
		--!!Split
		[16] = {PhysicalProperties.new,Flags[5] and 'ddddd' or 'fffff'},
		--!!Split
		[17] = {NumberRange.new,Flags[5] and 'dd' or 'ff'},
		--!!Split
		[18] = {UDim.new,Flags[5] and 'di2' or 'fi2'},
		--!!Split
		[19] = function()
			return Ray.new(Vector3.new(Parse(Flags[5] and 'ddd' or 'fff')),Vector3.new(Parse(Flags[5] and 'ddd' or 'fff')))
		end
		--!!End
	}

	for i = 1,ValuesLength do
		local TypeAndModifier = Parse('B')
		local Type = bit32.band(TypeAndModifier,0b11111)
		local Modifier = (TypeAndModifier - Type) / 0b100000
		local Decoder = ValueDecoders[Type]
		if type(Decoder)=='function' then
			Values[i] = Decoder(Modifier,i)
		else
			Values[i] = Decoder[1](Parse(Decoder[2]))
		end
	end

	for i,t in pairs(CFrameIndexes) do
		Values[t[1]] = CFrame.fromMatrix(Values[t[2]],Values[t[3]],Values[t[4]])
	end

	local InstancesLength = Parse(InstanceFMT)
	local Instances = {}
	local NoParent = {}

	for i = 1,InstancesLength do
		local ClassName = Values[Parse(ValueFMT)]
		local obj
		local MeshPartMesh,MeshPartScale
		if ClassName == "UnionOperation" then
			obj = DecodeUnion(Values,Flags,Parse)
			obj.UsePartColor = true
		elseif ClassName:find("Script") then
			obj = Instance.new("Folder")
			Script(obj,ClassName=='ModuleScript')
		elseif ClassName == "MeshPart" then
			obj = Instance.new("Part")
			MeshPartMesh = Instance.new("SpecialMesh")
			MeshPartMesh.MeshType = Enum.MeshType.FileMesh
			MeshPartMesh.Parent = obj
		else
			obj = Instance.new(ClassName)
		end
		local Parent = Instances[Parse(InstanceFMT)]
		local PropertiesLength = Parse(PropertyLengthFMT)
		local AttributesLength = Parse(PropertyLengthFMT)
		Instances[i] = obj
		for i = 1,PropertiesLength do
			local Prop,Value = Values[Parse(ValueFMT)],Values[Parse(ValueFMT)]

			local dont = false
			-- ok this looks awful
			if MeshPartMesh then
				if Prop == "MeshId" then
					MeshPartMesh.MeshId = Value
					dont = true
				elseif Prop == "TextureID" then
					MeshPartMesh.TextureId = Value
					dont = true
				elseif Prop == "Size" then
					if not MeshPartScale then
						MeshPartScale = Value
					else
						MeshPartMesh.Scale = Value / MeshPartScale
					end
				elseif Prop == "MeshSize" then
					if not MeshPartScale then
						MeshPartScale = Value
						MeshPartMesh.Scale = obj.Size / Value
					else
						MeshPartMesh.Scale = MeshPartScale / Value
					end
					dont = true
				end
			end

			if(not dont)then
				obj[Prop] = Value
			end
		end
		if MeshPartMesh then
			if MeshPartMesh.MeshId=='' then
				if MeshPartMesh.TextureId=='' then
					MeshPartMesh.TextureId = 'rbxasset://textures/meshPartFallback.png'
				end
				MeshPartMesh.Scale = obj.Size
			end
		end
		for i = 1,AttributesLength do
			obj:SetAttribute(Values[Parse(ValueFMT)],Values[Parse(ValueFMT)])
		end
		if not Parent then
			table.insert(NoParent,obj)
		else
			obj.Parent = Parent
		end
	end

	local ConnectionsLength = Parse(ConnectionFMT)
	for i = 1,ConnectionsLength do
		local a,b,c = Parse(InstanceFMT),Parse(ValueFMT),Parse(InstanceFMT)
		Instances[a][Values[b]] = Instances[c]
	end

	return NoParent
end


local Objects = Decode('AEBsASEGRm9sZGVyIQROYW1lIQdFbXBlcm9yIQhNZXNoUGFydCEITGVmdCBBcm0hCEFuY2hvcmVkIiEKQnJpY2tDb2xvcgfHACEGQ0ZyYW1lBBQARQFGASEKQ2FuQ29sbGlkZQIhCENhblRvdWNoIQVDb2xvcgZjX2IhCE1hdGVyaWFsAwAAAAAAgJhAIQhQb3NpdGlv'
	..'bgo+rk5B5GiOQIyb08AhBFNpemUKAACAPwAAAEAAAIA/IQZNZXNoSWQhHXJieGFzc2V0Oi8vZm9udHMvbGVmdGFybS5tZXNoIQhNZXNoU2l6ZSEITGVmdCBMZWcEHABFAUYBCj6uXkHI0RxAjJvTwCEdcmJ4YXNzZXQ6Ly9mb250cy9sZWZ0bGVnLm1lc2ghCVJpZ2h0'
	..'IEFybQQgAEUBRgEKPq5+QeRojkCMm9PAIR5yYnhhc3NldDovL2ZvbnRzL3JpZ2h0YXJtLm1lc2ghBEJlYW0hBkNoYWluMiELQXR0YWNobWVudDAhC0F0dGFjaG1lbnQxKAIAAAAAAA3/AACAPwAN/yEKQ3VydmVTaXplMAMAAAAAAADwPyEKQ3VydmVTaXplMQMAAAAA'
	..'AADwvyENTGlnaHRFbWlzc2lvbiEOTGlnaHRJbmZsdWVuY2UDAAAAAAAA4D8hB1RleHR1cmUhF3JieGFzc2V0aWQ6Ly80NTI3NDY1MTE0IQ1UZXh0dXJlTGVuZ3RoAwAAAAAAAABAIQxUZXh0dXJlU3BlZWQDAAAAoJmZ2T8hDFRyYW5zcGFyZW5jeSkCAAAAAAAAAAAA'
	..'AAAAAACAPwAAAAAAAAAAIQZXaWR0aDAhBldpZHRoMSEKQXR0YWNobWVudAQ6AEUBRgEKAAAAAM3MzL4zMzO/IQtBdHRhY2htZW50MgQ9AEUBRgEKAAAAAM3MzL4zMzM/IQZDaGFpbjEhBU1vZGVsIQpIYW5kQ2Fubm9uIQpXb3JsZFBpdm90BEcBSAFJASEEUGFydCEL'
	..'QmFja1N1cmZhY2UDAAAAAAAAJEAhDUJvdHRvbVN1cmZhY2UH6wMETwBKAUsBBhERESEMRnJvbnRTdXJmYWNlIQtMZWZ0U3VyZmFjZQMAAAAAAAByQCELT3JpZW50YXRpb24KAAAAAAAANEMAADRDCjy0fkE0JIc/ilvvwCEMUmlnaHRTdXJmYWNlIQhSb3RhdGlvbgoA'
	..'ADRDAAAAAAAAAAAKmplZPq5HgT2amVk+IQpUb3BTdXJmYWNlIQxDeWxpbmRlck1lc2ghDlVuaW9uT3BlcmF0aW9uBy8BBFsASAFJAQYAELAKAAC0QgAAAAAAAAAACjy0fkEKkh9AJvXawAoAAoA+bmbGP/7MMEAhDFVzZVBhcnRDb2xvcgoAAEA+0cyMPmZmZj4KPLR+'
	..'QReSWUBZKODACgAAgD8AAIA/AACAPwoAAAAAAAAAAAAAAAAKAACAPpeZKT+Ymbk+Cjy0fkFRxU5A9MHMwAoAALTCAAA0QwAAAAAKLzNjPzIz8z4AAEA+Cjy0fkHoXkRAWyjswAoAAAAAAAC0wgAAtEIKAQCAPtDM7D4BAIA+Cjy0fkGsKztA7cHewAqbmVk+x8zsPhIA'
	..'gD4KPLR+QYn4SUDxwd7ACgAAgD4AAIA+AACAPgo8tH5BHVeeP+3B5cAKlpnRPwAAgD4AAIA+Cjy0fkEgkgtA8MHlwAo8tH5BVcVYQPnB3sAKAAC0QgAANEMAAAAACszMzD2YmSk/EgCAPgo8tH5BLpJdQPfBzMAKAACAPpiZKT+Ymbk+Cjy0fkHwXmxA9MHMwCEEV2Vs'
	..'ZCECQzEETAFNAU4BIQVQYXJ0MCEFUGFydDEETwFQAVEBBFIBUwFUASEGQlRXZWxkBFUBSAFJAQcaAASCAFYBVwEGGyo1CkS0fkFZxVJAWijbwAoAALTCAAC0wgAAAAAKRgCYPwwAyD8AAKA+CpqZGT6ZmRk/MzODPgo8tH5B515eQPPBy8AKMzODPpiZGT9mZqY+Cjy0'
	..'fkGoK09A9cHLwAozM4M+YWZmPgIAAD4KPLR+QWvFQEAk9djACjMzgz6ZmRk/zMysPgo8tH5BnvhtQPvBy8AK//8PP/v/3z4AAKA+Cjy0fkFGxT5AWyjtwAozM4M+YWZmPjQz8z4KPLR+Qaf4U0Al9djAB/MDBJQAWAFZAQYAIGAKrM5+QWLFIkBeKNrACgAAtMIAAAAA'
	..'AAA0QwqAg10/BgDwP4ZmQkAKMDOzPpyZ2T41M3M+Cjy0fkFlxVJA+MHHwAowM7M+l5nZPjIzAz8KPLR+QRmSc0D4wcfACjAzsz7KzAw+lZk5Pwo8tH5BFV9WQFwow8AKAAC0wgAAAAAAAAAACsvMDD4CAOA+QTOzPgo8tH5BYMVeQMGOx8AKMDOzPpiZGT5hZhY/Cjy0'
	..'fkHWK3FAx46+wAowM7M+l5kZPpGZ+T4KPLR+QWHFTkDHjr7AIQ9Db3JuZXJXZWRnZVBhcnQK/MrMPTDKzD7TyMw9CkriekHZLNk/UCvuwAoAAPBBSgxwwfT90UIK0sjMPTDKzD79ysw9CshIekHt4eM/DeTswAqTGGPCfb8swkRL5EIK/crMPS/KzD7SyMw9Co2kekEf'
	..'SOo/QJHvwAoMAvDBff8kQ/r+0cIK08jMPS/KzD79ysw9CiU+e0Fhk98/itjwwAqHFmNCns8IQ0pM5MIKQnaBQWa/HECUD/HACilc9sEAQBxDg0DfQgrSyMw9L8rMPv7KzD0KDpSBQZzbIUAoMe/ACsP1U8LdJGBByXbzwgo8TYFB55QeQBqt7MAKHVr2QfT9vcGJQd/C'
	..'CtLIzD0vysw+/crMPQpkL4FBrngZQHuL7sAKw/VTQu78JcNSePNCCkRmZj75/38+MzOzPgo8tH5BxStXQCP18MAKMzOzPgYAgD6amZk+Cjy0fkGw+GdAKvXwwAozM7M+pZlZPs3M7D4KPLR+QXHFYkDBjunACjMzsz7LzOw+zMyMPgo8tH5ByytHQMeO7cAKzcxMPcvM'
	..'zD3MzEw+ClKNgEGk+EdAwI72wAr3/38/AACAPwAAgD8KzcxMPcvMzD3NzEw9Ck6NgEGT+D9Avo72wAr3/38/AACAP/X/fz8K1E18QZP4P0C+jvbACtRNfEGk+EdAwI72wApx/389jJlZPjMzsz4KPLR+QY74UUDDjunACjMzsz54ZuY9ZmamPgo8tH5B/l4yQCL15cAK'
	..'f/9/PdH/fz0zM7M+Cjy0fkGM+ClA8sHowAozM7M+MjMzPjIzMz4KPLR+QVVXlj8i9ebACsjMzD8wM7M+MzOzPgo8tH5BoIrxP5Bb78AKMzOzPj0zMz5sZuY9Cjy0fkEtvtA/LPXmwArMzEw+zcxMPc3MTD0KPLR+QeK9vD++jvfAAwAAAAAAABhACgAAgD/z/z8/9f//'
	..'PgrNzEw9y8zMPQAAgD4KUo2AQQ3x3z+7jvbACqQaf0Hivbw/vo73wAoAAIA/+v8/P+v//z4K1E18QQ3x3z+7jvbACjMzsz44M9M+aGaGPgo8tH5BDF80QIhb7sAK8/+fPiMzMz4zM7M+Cjy0fkGtirU/GvXmwArUTX5B4r28P76O98AKAAAAAAAAtEIAALTCCszMTD71'
	..'/389l5mZPQo8tH5B+r28Pyb19cAKAACAPvX/fz0AAIA+Cjy0fkE8JIc/iFvvwAMAAAAAAAAQQAozM7M+PTMzPpyZ2T4KPLR+QQZfGkAm9ebACgAAgD7MzMw9zcxMPQpSjYBBRvG/P8KO9sAKAACAPwAAgD/6/38/Cs3MTD3LzMw9yMzMPQpOjYBBmoqpP7OO9sAKAACA'
	..'PsjMzD3NzEw9CtRNfEFG8b8/wo72wCEESG9sZQMAAAAAAAAAAAT3AFoBWwEKMq9+QV5whj8CTO/ACs3MzD3NzMw9zczMPQRcAV0BXgEhBVNwaWtlBP0AXwFgAQoAAHDBAAAAAAAAcMIKB4qDQXTFkUBZr9jACszMzD4yMzM/zMzMPgrMyEw+vjAzPxnNTD4KnSODQYdG'
	..'lUCmT9bAChkEcMEAAAAAAABwwgoZzUw+vzAzP8zITD4KbfCDQUXsj0Bw4NTACqAaY0I5tINC+n7hwQoZzUw+vjAzP8zITD4KsCODQc2ek0AwftzACqAaY8LHS+TC4XrhQQrMyEw+vzAzPxnNTD4KcPCDQSlEjkDmDtvACjEIcEG+/zPDAABwQgQNAWEBYgEKAACWQgAA'
	..'AAAAAHDCCgeKg0F0xaFAvRXPwArMyEw+vjAzPxjNTD4KnSODQcFln0CqlMvACn3/lUJvEgM7+v5vwgpt8INBi/adQOzu0MAKfT9PQY8iFUP0vaRCCrAjg0FLlKVAZDzNwAp9P0/Bhev2wfq+pMIKcPCDQQElpEAIl9LACvr+lcK4/jPD4fpvQgRjAWQBZQEEZgFnAWgB'
	..'IQlSaWdodCBMZWcEGwFFAUYBCj6ubkHI0RxAjJvTwCEecmJ4YXNzZXQ6Ly9mb250cy9yaWdodGxlZy5tZXNoIQVUb3JzbwQfAUUBRgEKPq5mQeRojkCMm9PACgAAAEAAAABAAACAPwQjAWkBagEKAAAAgAAAAAAAALRCCgAAAAAAAAC/AAAAPwQlAUUBRgEKAAAAAAAA'
	..'AAAAAIBAIQVDaGFpbiEKRmFjZUNhbWVyYSEIU2VnbWVudHMDAAAAAAAANEAhC1RleHR1cmVNb2RlKQIAAAAAAAAAAAAAAAAAAIA/AACAPwAAAAAhBEhlYWQELgFFAUYBCj6uZkHeaL5AjJvTwAqamZk/mpmZP5qZmT8hGnJieGFzc2V0Oi8vZm9udHMvaGVhZC5tZXNo'
	..'Ch5TmT8N6Zk/HlOZPwQ0AWsBRgEKAAAAgAAAoMIAAAAACpqZmb7NzMw+zcxMvigCAAAAAAAA/wAAgD8AAP8DAAAAQDMz4z8EOAFFAUYBCpqZmb6amdk/AAAAvyELQXR0YWNobWVudDQEOwFFAUYBCpqZmT6amdk/AAAAvwMAAABAMzPjvyELQXR0YWNobWVudDMEQAFs'
	..'AUYBCgAAAIAAAMjCAAAAAAqamZk+zczMPs3MTL4hB1JlbW90ZXMhC1JlbW90ZUV2ZW50IQlLZXlfTW91c2UhBkNhbWVyYQoAAIA/AAAAAAAAAAAKAAAAAAAAgD8AAAAACj6ufkHoaI5AjJvTwAr//38/AAAAAC3eTLIKLt5MMqZ39zQAAIA/Cv3/fz8AAAAAK95Msgrk'
	..'pd8nAACAv9O7CzUKAAAAAC0zI7/e/7c/Cv7/fz8AAAAAAAAAAAoAAAAAAAAAMwAAgD8KAIDTO22ZKb+OZr6/Cv7/f78AAAAAAAAAAAoAAAAAAAAAMwAAgL8KPjMPwJSZIT8AAAA3CgAAAAAAAAAA/v9/vwoAAIC/AAAAAAAAAAAKAEChOrezuD/itiI/CuSl36cAAIA/'
	..'07sLtQou3kyypnfntAAAgL8K+/9/vwAAAIAp3kwyCi7eTDKmd9c0AACAPwr+/38/IN7MpQ4AACcKIN7MpQAAgD8AAACzCgDAv7qQM2s+e3/6vwr//38/Lt5MMgHY0icKAAAAAKZ39zQAAIC/Cv///z7vJVa/7IVlPgrXs10/6kb3PuaDBL4K/v//PuqFZb7vJVa/Ctaz'
	..'XT/lgwQ+6kb3PgoAUw6+QJsGv/QYAT4K////PtezXT8AAAAACu8lVr/qRvc+54OEPgoAnAy8gOEZvxhADD8K/v//PtazXT8AAAAACuqFZb7lgwQ+60Z3vwouvTuzAACAPwAAAAAKAACAvy69O7MAAAAACs/QMT4AAAAAXRx8PwrV0DG+AAAAAFwcfD8oAQAAAQACAAMA'
	..'AQABAAAEAAIMAAIABQAGAAcACAAJAAoACwAMAA0ADgANAA8AEAARABIAEwAUABUAFgAXABgAGQAWAAQAAgwAAgAaAAYABwAIAAkACgAbAAwADQAOAA0ADwAQABEAEgATABwAFQAWABcAHQAZABYABAACDAACAB4ABgAHAAgACQAKAB8ADAANAA4ADQAPABAAEQASABMA'
	..'IAAVABYAFwAhABkAFgAiAAUMAAIAIwAPACYAJwAoACkAKgArACgALAAtAC4ALwAwADEAMgAzADQANQA2ADMANwAzADgABQIACgA5ABMAOgA4AAUDAAIAOwAKADwAEwA9ACIABQwAAgA+AA8AJgAnACoAKQAoACsAKAAsAC0ALgAvADAAMQAyADMANAA1ADYAMwA3ADMA'
	..'PwAFAgACAEAAQQBCAEMAChAARABFAEYARQAIAEcACgBIAAwADQAOAA0ADwBJAEoARQBLAEUAEQBMAE0ATgATAE8AUABFAFEAUgAVAFMAVABFAFUACwAAVgBACgFDAF4AXwBaADEAYABhAAFDAGIAYwBkADEAYABhAABDAGUAZgBnAAFDAGgAaQBkADEAYABhAABDAGoA'
	..'awBnAAFDAGwAbQBkADEAYABhAABDAG4AbwBnAAFDAGgAcABxADEAYABhAABDAHIAcwBnAAFDAHQAdQBxADEAYABhAAoLAAgAVwAKAFgADAANAA4ADQAPAFkAEQASAE0AWgATAFsAUQBaABUAXABdAAcAdgANAQB3AHgAdgANAQB3AHsAdgANAQB3AHwAdgANAgACAH0A'
	..'dwB+AFYAQAYAQwCFAIYAZwABQwCHAIgAZAAxAGAAYQABQwCJAIoAZAAxAGAAYQABQwCLAIwAcQAxAGAAYQAAQwCNAI4AZwABQwCPAJAAcQAxAGAAYQAKCgAIAH8ACgCAAAwADQAOAA0ADwCBABEAEgBNAGcAEwCCAFEAgwAVAIQAVgBABUAGAUMAlwCYAGQAMQBgAGEA'
	..'AUMAmQCaAHEAMQBgAGEAAUMAmwCcAJ0AMQBgAGEAAEMAngCfAGcAAUMAoAChAFoAMQBgAGEAAUMAogCjAGQAMQBgAGEAQAQApAClAKYApwAApACoAKkAqgAApACrAKwArQAApACuAK8AsABABACkAKsAsQCyAACkALMAtAC1AACkAKsAtgC3AACkALgAuQC6AEAJAEMA'
	..'uwC8AGcAAUMAvQC+AHEAMQBgAGEAAUMAvwDAAFoAMQBgAGEAAUMAwQDCAGQAMQBgAGEAAUMAwwDEAHEAMQDFAGEAAUMAxgDHAJ0AMQDIAGEAAUMAxgDJAJ0AMQDIAGEAAUMAwwDKAHEAMQDFAGEAAEMAywDMAGcAQBIBQwDNAM4AWgAxAGAAYQAAQwDPANAAZwABQwDR'
	..'ANIAZAAxAGAAYQAAQwDTANQAZwABQwDVANYAWgAxAGAAYQABQwDXANgAZwDZANoAYQABQwDbANwAcQAxAMUAYQABQwDXAN0AZwAxAN4AYQABQwDbAN8AcQAxAMUAYQABQwDgAOEAcQAxAGAAYQAAQwDiAOMAZwABQwDXAOQA5QAxAN4AYQAAQwDmAOcAZwABQwDoAOkA'
	..'TgDqAGAAYQABQwDrAOwAZAAxAGAAYQABQwDtAO4AZwDZAO8AYQABQwDwAPEAnQAxAMUAYQABQwDyAPMAZwDZAO8AYQAKCgAIAJEACgCSAAwADQAOAA0ADwCTABEAEgBNAGQAEwCUAFEAlQAVAJYAQwAKCQACAPQARgD1AAoA9gAMAA0ADgANABMA9wAVAPgAVAD1ADQA'
	..'KAB2AAoBAHcA+QBWAEAEAKQA/wAAAQEBAKQAAgEDAQQBAKQABQEGAQcBAKQACAEJAQoBBQwAAgD6AAgAkQAKAPsADAANAA4ADQAPAJMAEQASAE0A/AATAP0AUQD8ABUA/gBdAAcAVgBABACkAA4BDwEQAQCkAAUBEQESAQCkAAUBEwEUAQCkAP8AFQEWAQUMAAIA+gAI'
	..'AJEACgALAQwADQAOAA0ADwCTABEAEgBNAAwBEwANAVEADAEVAP4AXQAHAHYABQIAAgB9AHcAFwF2AAUCAAIAfQB3ABgBBAACDAACABkBBgAHAAgACQAKABoBDAANAA4ADQAPABAAEQASABMAGwEVABYAFwAcARkAFgAEAAIMAAIAHQEGAAcACACRAAoAHgEMAA0ADgAN'
	..'AA8AkwARABIAEwAfARUAIAEXACEAGQAWADgAGwMACgAhAU0AIgETACMBOAAbAwACADsACgAkARMAJQEiABsMAAIAJgEPACYAJwAqACkAKAAnAQcAKwAoACgBKQEuAC8AMAAxACoBKAA0ACsBNwD1AAQAAgwAAgAsAQYABwAIAAkACgAtAQwADQAOAA0ADwAQABEAEgAT'
	..'AC4BFQAvARcAMAEZADEBOAAfAwAKADIBTQAzARMANAEiAB8KAAIAPgAPADUBJwAqACkANgEnAQcAKwAoAC4ALwAqASgANAArATcA9QA4AB8DAAIAOwAKADcBEwA4ATgAHwMAAgA5AQoAOgETADsBIgAfCgACACMADwA1AScAKgApADwBJwEHACsAKAAuAC8AKgEoADQA'
	..'KwE3APUAOAAfBAACAD0BCgA+AU0APwETAEABAQABAQACAEEBQgEmAQACAEMBQgEmAQACAEQBGAYkAAcGJQAICSQACAklAAcOeQALDnoADQ95AAsPegATEHkACxB6ABIReQANEXoAFBV5AAUVegANGHkABRh6ABYZeQAFGXoAFx4kABweJQAdISQAICElACIkJAAlJCUA'
	..'Iw==')
for _,obj in pairs(Objects) do
	obj.Parent = workspace
end




game.TextChatService.BubbleChatConfiguration.Enabled = false

local Terrible = game.Workspace.Emperor

table.foreach(game.Workspace.Emperor.Folder.Torso:GetChildren(),function(i,v) v.Parent = owner.Character.Torso end)
table.foreach(game.Workspace.Emperor.Folder.Head:GetChildren(),function(i,v) v.Parent = owner.Character.Head end)

table.foreach(Terrible:GetChildren(),function(i,v) v.Parent = script end)

--// Core Stuff

script.Parent = owner.PlayerGui

local Player = owner
local Character = owner.Character

local Ignores = {}

local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Torso, RootPart, RightArm, LeftArm, RightLeg, LeftLeg, Head = Character.Torso, Character.HumanoidRootPart, Character["Right Arm"], Character["Left Arm"], Character["Right Leg"], Character["Left Leg"], Character.Head
local Humanoid = Character:FindFirstChildOfClass("Humanoid")


local cf = {n = CFrame.new, a = function(_1,_2,_3,norad) if not norad then return CFrame.Angles(math.rad(_1),math.rad(_2),math.rad(_3)) else return CFrame.Angles(_1,_2,_3) end end; r = function(min,max) return CFrame.Angles(math.rad(math.random(min,max)),math.rad(math.random(min,max)),math.rad(math.random(min,max))) end;}
local cos, sin, rad, cotan = math.cos, math.sin, math.rad, function(e) return math.sin(e/2)*math.cos(e/2) end
local sine = 0

--// Setup main functions.

function Change(instance : Instance, props : table)
	props = props or {}
	table.foreach(props, function(i,v) instance[i] = v end)
end

function Create(class : string, props)
	local part = Instance.new(class)
	Change(part,props)
	return part
end

function Remove(item, time)
	if string.lower(typeof(item)) == "instance" then
		game:GetService("Debris"):AddItem(item, time or 0)
	elseif string.lower(typeof(item)) == "table" then
		table.foreach(item, function(i,v) game:GetService("Debris"):AddItem(v, time or 0) end)
	end
end

function Raycast(pos, v3, ignore)
	local Ray = Ray.new(pos,v3)
	local RayPart, RayPosition, Normal = workspace:FindPartOnRayWithIgnoreList(Ray, ignore, false, true)
	return RayPart, RayPosition, Normal
end

function Tween(Data : {EaseStyle : Enum.EasingStyle, EaseDirection : Enum.EasingDirection, Object : Instance, Time : number, Properties : table}, WaitOnComplete : boolean)
	if not Data.Object then return warn("Couldn't tween. No object?") end
	if not Data.Properties then return warn("Couldn't tween. No properties?") end
	local EasingStyle = Data.EaseStyle or Enum.EasingStyle.Sine
	local EasingDirection = Data.EaseDirection or Enum.EasingDirection.InOut
	local Time = Data.Time or 1

	TweenService:Create(Data.Object, TweenInfo.new(Time, EasingStyle, EasingDirection), Data.Properties):Play()

	if WaitOnComplete then
		task.wait(Time)
	end
end

function SoundEffect(Id,Volume,Pitch,Parent, Looped)
	local sound = Create("Sound", {SoundId = "rbxassetid://"..tostring(Id), Volume = Volume or 1, Pitch = Pitch or 1, Parent = Parent or Character.HumanoidRootPart, Looped = Looped or false})
	sound:Play()
	task.spawn(function() if Looped then return end sound.Loaded:Connect(function() Remove(sound,sound.TimeLength/sound.Pitch) end) if sound.IsLoaded then Remove(sound,sound.TimeLength/sound.Pitch) end end)
	return sound
end

--// Joints

Remove({Character:FindFirstChild("Animate"), Humanoid:FindFirstChildOfClass("Animator")})

Remove({Torso.Neck, Torso["Right Shoulder"], Torso["Right Hip"], Torso["Left Shoulder"], Torso["Left Hip"], RootPart.RootJoint})

local Joints = {
	Torso = {Joint = Create("Motor6D", {Name = "RootJoint", Parent = RootPart, Part0 = RootPart, Part1 = Torso, C0 = cf.n(), C1 = cf.n()})};
	Head = {Joint = Create("Motor6D", {Name = "Neck", Parent = Torso, Part0 = Torso, Part1 = Head, C0 = cf.n(), C1 = cf.n()})};
	RightArm = {Joint = Create("Motor6D", {Name = "Right Shoulder", Parent = Torso, Part0 = Torso, Part1 = RightArm, C0 = cf.n(), C1 = cf.n()})};
	LeftArm = {Joint = Create("Motor6D", {Name = "Left Shoulder", Parent = Torso, Part0 = Torso, Part1 = LeftArm, C0 = cf.n(), C1 = cf.n()})};
	RightLeg = {Joint = Create("Motor6D", {Name = "Right Hip", Parent = Torso, Part0 = Torso, Part1 = RightLeg, C0 = cf.n(), C1 = cf.n()})};
	LeftLeg = {Joint = Create("Motor6D", {Name = "Left Hip", Parent = Torso, Part0 = Torso, Part1 = LeftLeg, C0 = cf.n(), C1 = cf.n()})};
}

table.foreach(Joints, function(i,v) v.Default = v.Joint.C0 end)

--// Animation functions

function OGAnimate(data,lerp)
	local lerp = lerp or .1
	local success, result = pcall(function()
		table.foreach(data, function(i,v)
			if Joints[i] then
				if data.RootLocked and (i == "RightLeg" or i == "LeftLeg") then
					Joints[i].Joint.Part0 = RootPart
				elseif not data.RootLocked and (i == "RightLeg" or i == "LeftLeg") then
					Joints[i].Joint.Part0 = Torso
				end
				Joints[i].Joint.C0 = Joints[i].Joint.C0:Lerp(Joints[i].Default*v, lerp)
			end
		end)
	end)
	if not success then
		error("Animation error occurred. Output: "..result)
	end
end

Animate = function(tbl, time)
	pcall(function()
		Joints.Torso.Joint.C0 = Joints.Torso.Joint.C0:Lerp(tbl[1], time)
		Joints.LeftArm.Joint.C0 = Joints.LeftArm.Joint.C0:Lerp(tbl[2], time)
		Joints.LeftLeg.Joint.C0 = Joints.LeftLeg.Joint.C0:Lerp(tbl[3], time)
		Joints.RightArm.Joint.C0 = Joints.RightArm.Joint.C0:Lerp(tbl[4], time)
		Joints.RightLeg.Joint.C0 = Joints.RightLeg.Joint.C0:Lerp(tbl[5], time)
		Joints.Head.Joint.C0 = Joints.Head.Joint.C0:Lerp(tbl[6], time)
		--Joints.Axe = Joints.Axe:Lerp(tbl[7], time)
	end)
end

--// Lightning

local clock = os.clock

function DiscretePulse(input, s, k, f, t, min, max) --input should be between 0 and 1. See https://www.desmos.com/calculator/hg5h4fpfim for demonstration.
	return math.clamp( (k)/(2*f) - math.abs( (input - t*s + 0.5*(k)) / (f) ), min, max )
end

function NoiseBetween(x, y, z, min, max)
	return min + (max - min)*(math.noise(x, y, z) + 0.5)
end

function CubicBezier(p0, p1, p2, p3, t)
	return p0*(1 - t)^3 + p1*3*t*(1 - t)^2 + p2*3*(1 - t)*t^2 + p3*t^3
end

local BoltPart = Instance.new("Part")
BoltPart.TopSurface, BoltPart.BottomSurface = 0, 0
BoltPart.Anchored, BoltPart.CanCollide = true, false
BoltPart.Shape = "Cylinder"
BoltPart.Name = "BoltPart"
BoltPart.Material = Enum.Material.Neon
BoltPart.Color = Color3.new(1, 1, 1)
BoltPart.Transparency = 1
table.insert(Ignores, BoltPart)

local rng = Random.new()
local xInverse = CFrame.lookAt(Vector3.new(), Vector3.new(1, 0, 0)):inverse()

local ActiveBranches = {}

local LightningBolt = {}
LightningBolt.__index = LightningBolt

--Small tip: You don't need to use actual Roblox Attachments below. You can also create "fake" ones as follows:
--[[
local A1, A2 = {}, {}
A1.WorldPosition, A1.WorldAxis = chosenPos1, chosenAxis1
A2.WorldPosition, A2.WorldAxis = chosenPos2, chosenAxis2
local NewBolt = LightningBolt.new(A1, A2, 40)
--]]

function LightningBolt.new(Attachment0, Attachment1, PartCount)
	local self = setmetatable({}, LightningBolt)

	--Main (default) Properties--

	--Bolt Appearance Properties--
	self.Enabled = true --Hides bolt without destroying any parts when false
	self.Attachment0, self.Attachment1 = Attachment0, Attachment1 --Bolt originates from Attachment0 and ends at Attachment1
	self.CurveSize0, self.CurveSize1 = 0, 0 --Works similarly to beams. See https://dk135eecbplh9.cloudfront.net/assets/blt160ad3fdeadd4ff2/BeamCurve1.png
	self.MinRadius, self.MaxRadius = 0, 2.4 --Governs the amplitude of fluctuations throughout the bolt
	self.Frequency = 1 --Governs the frequency of fluctuations throughout the bolt. Lower this to remove jittery-looking lightning
	self.AnimationSpeed = 7 --Governs how fast the bolt oscillates (i.e. how fast the fluctuating wave travels along bolt)
	self.Thickness = 1 --The thickness of the bolt
	self.MinThicknessMultiplier, self.MaxThicknessMultiplier = 0.2, 1 --Multiplies Thickness value by a fluctuating random value between MinThicknessMultiplier and MaxThicknessMultiplier along the Bolt

	--Bolt Kinetic Properties--
	--Allows for fading in (or out) of the bolt with time. Can also create a "projectile" bolt
	--Recommend setting AnimationSpeed to 0 if used as projectile (for better aesthetics)
	--Works by passing a "wave" function which travels from left to right where the wave height represents opacity (opacity being 1 - Transparency)
	--See https://www.desmos.com/calculator/hg5h4fpfim to help customise the shape of the wave with the below properties
	self.MinTransparency, self.MaxTransparency = 0, 1 --See https://www.desmos.com/calculator/hg5h4fpfim
	self.PulseSpeed = 2 --Bolt arrives at Attachment1 1/PulseSpeed seconds later. See https://www.desmos.com/calculator/hg5h4fpfim
	self.PulseLength = 1000000 --See https://www.desmos.com/calculator/hg5h4fpfim
	self.FadeLength = 0.2 --See https://www.desmos.com/calculator/hg5h4fpfim
	self.ContractFrom = 0.5 --Parts shorten or grow once their Transparency exceeds this value. Set to a value above 1 to turn effect off. See https://imgur.com/OChA441

	--Bolt Color Properties--
	self.Color = Color3.new(1, 1, 1) --Can be a Color3 or ColorSequence
	self.ColorOffsetSpeed = 1 --Sets speed at which ColorSequence travels along Bolt

	--

	self.Parts = {} --The BoltParts which make up the Bolt


	local a0, a1 = Attachment0, Attachment1
	local parent = workspace
	local p0, p1, p2, p3 = a0.WorldPosition, a0.WorldPosition + a0.WorldAxis*self.CurveSize0, a1.WorldPosition - a1.WorldAxis*self.CurveSize1, a1.WorldPosition
	local PrevPoint, bezier0 = p0, p0
	local MainBranchN = PartCount or 30

	for i = 1, MainBranchN do
		local t1 = i/MainBranchN
		local bezier1 = CubicBezier(p0, p1, p2, p3, t1)
		local NextPoint = i ~= MainBranchN and (CFrame.lookAt(bezier0, bezier1)).Position or bezier1
		local BPart = BoltPart:Clone()
		BPart.Size = Vector3.new((NextPoint - PrevPoint).Magnitude, 0, 0)
		BPart.CFrame = CFrame.lookAt(0.5*(PrevPoint + NextPoint), NextPoint)*xInverse
		BPart.Parent = parent
		BPart.Locked, BPart.CastShadow = true, false
		table.insert(Ignores,BPart)
		self.Parts[i] = BPart
		PrevPoint, bezier0 = NextPoint, bezier1
	end

	self.PartsHidden = false
	self.DisabledTransparency = 1
	self.StartT = clock()
	self.RanNum = math.random()*100
	self.RefIndex = #ActiveBranches + 1

	ActiveBranches[self.RefIndex] = self

	return self
end

function LightningBolt:Destroy()
	ActiveBranches[self.RefIndex] = nil

	for i = 1, #self.Parts do
		self.Parts[i]:Destroy()

		if i%100 == 0 then wait() end
	end

	self = nil
end

local offsetAngle = math.cos(math.rad(90))

game:GetService("RunService").Heartbeat:Connect(function()

	for _, ThisBranch in pairs(ActiveBranches) do
		if ThisBranch.Enabled == true then
			ThisBranch.PartsHidden = false
			local MinOpa, MaxOpa = 1 - ThisBranch.MaxTransparency, 1 - ThisBranch.MinTransparency
			local MinRadius, MaxRadius = ThisBranch.MinRadius, ThisBranch.MaxRadius
			local thickness = ThisBranch.Thickness
			local Parts = ThisBranch.Parts
			local PartsN = #Parts
			local RanNum = ThisBranch.RanNum
			local StartT = ThisBranch.StartT
			local spd = ThisBranch.AnimationSpeed
			local freq = ThisBranch.Frequency
			local MinThick, MaxThick = ThisBranch.MinThicknessMultiplier, ThisBranch.MaxThicknessMultiplier
			local a0, a1, CurveSize0, CurveSize1 = ThisBranch.Attachment0, ThisBranch.Attachment1, ThisBranch.CurveSize0, ThisBranch.CurveSize1
			local p0, p1, p2, p3 = a0.WorldPosition, a0.WorldPosition + a0.WorldAxis*CurveSize0, a1.WorldPosition - a1.WorldAxis*CurveSize1, a1.WorldPosition
			local timePassed = clock() - StartT
			local PulseLength, PulseSpeed, FadeLength = ThisBranch.PulseLength, ThisBranch.PulseSpeed, ThisBranch.FadeLength
			local Color = ThisBranch.Color
			local ColorOffsetSpeed = ThisBranch.ColorOffsetSpeed
			local contractf = 1 - ThisBranch.ContractFrom
			local PrevPoint, bezier0 = p0, p0

			if timePassed < (PulseLength + 1) / PulseSpeed then

				for i = 1, PartsN do
					--local spd = NoiseBetween(i/PartsN, 1.5, 0.1*i/PartsN, -MinAnimationSpeed, MaxAnimationSpeed) --Can enable to have an alternative animation which doesn't shift the noisy lightning "Texture" along the bolt
					local BPart = Parts[i]
					local t1 = i/PartsN
					local Opacity = DiscretePulse(t1, PulseSpeed, PulseLength, FadeLength, timePassed, MinOpa, MaxOpa)
					local bezier1 = CubicBezier(p0, p1, p2, p3, t1)
					local time = -timePassed --minus to ensure bolt waves travel from a0 to a1
					local input, input2 = (spd*time) + freq*10*t1 - 0.2 + RanNum*4, 5*((spd*0.01*time) / 10 + freq*t1) + RanNum*4
					local noise0 = NoiseBetween(5*input, 1.5, 5*0.2*input2, 0, 0.1*2*math.pi) + NoiseBetween(0.5*input, 1.5, 0.5*0.2*input2, 0, 0.9*2*math.pi)
					local noise1 = NoiseBetween(3.4, input2, input, MinRadius, MaxRadius)*math.exp(-5000*(t1 - 0.5)^10)
					local thicknessNoise = NoiseBetween(2.3, input2, input, MinThick, MaxThick)
					local NextPoint = i ~= PartsN and (CFrame.new(bezier0, bezier1)*CFrame.Angles(0, 0, noise0)*CFrame.Angles(math.acos(math.clamp(NoiseBetween(input2, input, 2.7, offsetAngle, 1), -1, 1)), 0, 0)*CFrame.new(0, 0, -noise1)).Position or bezier1

					if Opacity > contractf then
						BPart.Size = Vector3.new((NextPoint - PrevPoint).Magnitude, thickness*thicknessNoise*Opacity, thickness*thicknessNoise*Opacity)
						BPart.CFrame = CFrame.lookAt(0.5*(PrevPoint + NextPoint), NextPoint)*xInverse
						BPart.Transparency = 1 - Opacity
					elseif Opacity > contractf - 1/(PartsN*FadeLength) then
						local interp = (1 - (Opacity - (contractf - 1/(PartsN*FadeLength)))*PartsN*FadeLength)*(t1 < timePassed*PulseSpeed - 0.5*PulseLength and 1 or -1)
						BPart.Size = Vector3.new((1 - math.abs(interp))*(NextPoint - PrevPoint).Magnitude, thickness*thicknessNoise*Opacity, thickness*thicknessNoise*Opacity)
						BPart.CFrame = CFrame.lookAt(PrevPoint + (NextPoint - PrevPoint)*(math.max(0, interp) + 0.5*(1 - math.abs(interp))), NextPoint)*xInverse
						BPart.Transparency = 1 - Opacity
					else
						BPart.Transparency = 1
					end

					if typeof(Color) == "Color3" then
						BPart.Color = Color
					else --ColorSequence
						t1 = (RanNum + t1 - timePassed*ColorOffsetSpeed)%1
						local keypoints = Color.Keypoints 
						for i = 1, #keypoints - 1 do --convert colorsequence onto lightning
							if keypoints[i].Time < t1 and t1 < keypoints[i+1].Time then
								BPart.Color = keypoints[i].Value:lerp(keypoints[i+1].Value, (t1 - keypoints[i].Time)/(keypoints[i+1].Time - keypoints[i].Time))
								break
							end
						end
					end

					PrevPoint, bezier0 = NextPoint, bezier1
				end

			else

				ThisBranch:Destroy()

			end

		else --Enabled = false

			if ThisBranch.PartsHidden == false then
				ThisBranch.PartsHidden = true
				local datr = ThisBranch.DisabledTransparency
				for i = 1, #ThisBranch.Parts do
					ThisBranch.Parts[i].Transparency = datr
				end
			end

		end
	end

end)

--// Lightning Sparks

local ActiveSparks = {}

local rng = Random.new()
local LightningSparks = {}
LightningSparks.__index = LightningSparks

function LightningSparks.new(LightningBolt, MaxSparkCount)
	local self = setmetatable({}, LightningSparks)

	--Main (default) properties--

	self.Enabled = true --Stops spawning sparks when false
	self.LightningBolt = LightningBolt --Bolt which sparks fly out of
	self.MaxSparkCount = MaxSparkCount or 10 --Max number of sparks visible at any given instance
	self.MinSpeed, self.MaxSpeed = 3, 6 --Min and max PulseSpeeds of sparks
	self.MinDistance, self.MaxDistance = 3, 6 --Governs how far sparks travel away from main bolt
	self.MinPartsPerSpark, self.MaxPartsPerSpark = 8, 10 --Adjustable

	--

	self.SparksN = 0
	self.SlotTable = {}
	self.RefIndex = #ActiveSparks + 1

	ActiveSparks[self.RefIndex] = self

	return self
end

function LightningSparks:Destroy()
	ActiveSparks[self.RefIndex] = nil

	for i, v in pairs(self.SlotTable) do
		if v.Parts[1].Parent == nil then
			self.SlotTable[i] = nil --Removes reference to prevent memory leak
		end
	end

	self = nil
end

function RandomVectorOffset(v, maxAngle) --returns uniformly-distributed random unit vector no more than maxAngle radians away from v
	return (CFrame.lookAt(Vector3.new(), v)*CFrame.Angles(0, 0, rng:NextNumber(0, 2*math.pi))*CFrame.Angles(math.acos(rng:NextNumber(math.cos(maxAngle), 1)), 0, 0)).LookVector
end 

game:GetService("RunService").Heartbeat:Connect(function ()

	for _, ThisSpark in pairs(ActiveSparks) do

		if ThisSpark.Enabled == true and ThisSpark.SparksN < ThisSpark.MaxSparkCount then

			local Bolt = ThisSpark.LightningBolt

			if Bolt.Parts[1].Parent == nil then
				ThisSpark:Destroy()
				return 
			end

			local BoltParts = Bolt.Parts
			local BoltPartsN = #BoltParts

			local opaque_parts = {}

			for part_i = 1, #BoltParts do --Fill opaque_parts table

				if BoltParts[part_i].Transparency < 0.3 then --minimum opacity required to be able to generate a spark there
					opaque_parts[#opaque_parts + 1] = (part_i - 0.5) / BoltPartsN
				end

			end

			local minSlot, maxSlot 

			if #opaque_parts ~= 0 then
				minSlot, maxSlot = math.ceil(opaque_parts[1]*ThisSpark.MaxSparkCount), math.ceil(opaque_parts[#opaque_parts]*ThisSpark.MaxSparkCount)
			end

			for _ = 1, rng:NextInteger(1, ThisSpark.MaxSparkCount - ThisSpark.SparksN) do

				if #opaque_parts == 0 then break end

				local available_slots = {}

				for slot_i = minSlot, maxSlot do --Fill available_slots table

					if ThisSpark.SlotTable[slot_i] == nil then --check slot doesn't have existing spark
						available_slots[#available_slots + 1] = slot_i
					end

				end

				if #available_slots ~= 0 then 

					local ChosenSlot = available_slots[rng:NextInteger(1, #available_slots)]
					local localTrng = rng:NextNumber(-0.5, 0.5)
					local ChosenT = (ChosenSlot - 0.5 + localTrng)/ThisSpark.MaxSparkCount

					local dist, ChosenPart = 10, 1

					for opaque_i = 1, #opaque_parts do
						local testdist = math.abs(opaque_parts[opaque_i] - ChosenT)
						if testdist < dist then
							dist, ChosenPart = testdist, math.floor((opaque_parts[opaque_i]*BoltPartsN + 0.5) + 0.5)
						end
					end

					local Part = BoltParts[ChosenPart]

					--Make new spark--

					local A1, A2 = {}, {}
					A1.WorldPosition = Part.Position + localTrng*Part.CFrame.RightVector*Part.Size.X
					A2.WorldPosition = A1.WorldPosition + RandomVectorOffset(Part.CFrame.RightVector, math.pi/4)*rng:NextNumber(ThisSpark.MinDistance, ThisSpark.MaxDistance)
					A1.WorldAxis = (A2.WorldPosition - A1.WorldPosition).Unit
					A2.WorldAxis = A1.WorldAxis
					local NewSpark = LightningBolt.new(A1, A2, rng:NextInteger(ThisSpark.MinPartsPerSpark, ThisSpark.MaxPartsPerSpark))

					--NewSpark.MaxAngleOffset = math.rad(70)
					NewSpark.MinRadius, NewSpark.MaxRadius = 0, 0.8
					NewSpark.AnimationSpeed = .4
					NewSpark.Thickness = Part.Size.Y / 2
					NewSpark.MinThicknessMultiplier, NewSpark.MaxThicknessMultiplier = 1, 1
					NewSpark.PulseLength = 0.5
					NewSpark.PulseSpeed = rng:NextNumber(ThisSpark.MinSpeed, ThisSpark.MaxSpeed)
					NewSpark.FadeLength = 0.25
					local cH, cS, cV = Color3.toHSV(Part.Color)
					NewSpark.Color = Color3.fromHSV(cH, 0.6, cV)

					ThisSpark.SlotTable[ChosenSlot] = NewSpark

					--

				end

			end

		end



		--Update SparksN--

		local slotsInUse = 0

		for i, v in pairs(ThisSpark.SlotTable) do
			if v.Parts[1].Parent ~= nil then
				slotsInUse = slotsInUse + 1
			else
				ThisSpark.SlotTable[i] = nil --Removes reference to prevent memory leak
			end
		end

		ThisSpark.SparksN = slotsInUse

		--
	end

end)

--// Camera and Mouse replication

local createFakeEvent = function()
	local t = {Functions = {}}
	t.Connect = function(Humanoid,f) Humanoid.Functions[#Humanoid.Functions+1] = f end
	t.connect = t.Connect
	return t
end

function fireFakeEvent(tbl,ev,...)
	local t = tbl[ev]
	if t and t.Functions then
		for i,v in pairs(t.Functions) do
			v(...)
		end
	else
		warn("so i didnt find the functions table or the table itHumanoid. oops!")
	end
end

local Mouse = {Hit = cf.n(); Target = nil; KeyDown = createFakeEvent(); KeyUp = createFakeEvent(); Button1Down = createFakeEvent(); Button1Up = createFakeEvent();}
local Camera = {CFrame = cf.n()}

--// Local

local client = nil

do
	client = NLS([[

		local blehparent = script.Parent
		print(blehparent.Name)

		--// unorganized mess. this is what i make

		local VisGUI = Instance.new("ScreenGui",script)
		VisGUI.Name = "VisGUI"
		VisGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		VisGUI.DisplayOrder = 999999999

		local Vis = Instance.new("Frame")
		Vis.Name = "Vis"
		Vis.AnchorPoint = Vector2.new(1, 1)
		Vis.Size = UDim2.new(0.2438905, 0, 0.1620843, 0)
		Vis.BackgroundTransparency = 1
		Vis.Position = UDim2.new(1, 0, 1, 0)
		Vis.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		Vis.Parent = VisGUI

		local UIListLayout = Instance.new("UIListLayout")
		UIListLayout.FillDirection = Enum.FillDirection.Horizontal
		UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		UIListLayout.Parent = Vis

		local VisFrame = Instance.new("Frame",script)
		VisFrame.Name = "VisFrame"
		VisFrame.LayoutOrder = 999999999
		VisFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		VisFrame.Size = UDim2.new(0, 5, 0, 20)
		VisFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
		VisFrame.BackgroundTransparency = 0.1
		VisFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

		local char = owner.Character
		if not char then
			repeat wait() until owner.Character
		end

		char = owner.Character
		local root = char.HumanoidRootPart
		local mouse = owner:GetMouse()
		local camera = workspace.CurrentCamera
		local hum = char:WaitForChild("Humanoid")

		local remotes = script:WaitForChild("Remotes")
		local remote1 = script.Remotes:WaitForChild("Key_Mouse")
		local remote2 = script.Remotes:WaitForChild("Camera")

		local input = function(io,a)
			if a then return end
			local io = {KeyCode=io.KeyCode,UserInputType=io.UserInputType,UserInputState=io.UserInputState}
			remote1:FireServer("i",io)
		end

		game:GetService("UserInputService").InputBegan:Connect(input)
		game:GetService("UserInputService").InputEnded:Connect(input)

		local ui = nil
		local vis = nil
		local visframe = nil
		local visframes = {}
		local mus = nil

		function hamming(fft_data)
			local N = #fft_data
			local window = {}
			for n = 0, N - 1 do
				window[n + 1] = fft_data[n + 1] * (0.54 - 0.46 * math.cos(2 * math.pi * n / (N - 1)))
			end
			return window
		end

		function hanning(fft_data)
			local N = #fft_data
			local window = {}
			for n = 0, N - 1 do
				window[n + 1] = fft_data[n + 1] * 0.5 * (1 - math.cos(2 * math.pi * n / (N - 1)))
			end
			return window
		end

		game:GetService("RunService").Heartbeat:Connect(function()
			char = owner.Character
			
			if char then
				root = char:WaitForChild("HumanoidRootPart")
				hum = char:WaitForChild("Humanoid")
			end
			
			mus = root:WaitForChild("Song")
			
			if not ui or not ui:IsDescendantOf(owner.PlayerGui) then
				ui = script.VisGUI:Clone()
				ui.Parent = owner.PlayerGui
				vis = ui.Vis
				visframe = script.VisFrame
				visframes = {}
				for i = 1, (vis.AbsoluteSize.X/visframe.AbsoluteSize.X) do
					local v = visframe:Clone()
					v.Parent = vis
					v.Name = i
					visframes[i] = v
				end
			end

			for i,v in next, visframes do
				if(not mus)then
					return
				end
				local noise = math.noise((tick()%1)/(i/(#visframes*math.random(1,2))), mus.PlaybackLoudness%1, 0)*240
				local col = math.clamp(mus.PlaybackLoudness/100*(i/(#visframes*math.random(1,2))), .1, 1)
				v.Size = v.Size:Lerp(UDim2.fromOffset(v.Size.X.Offset, (noise > 0 and noise or -noise)*(mus.PlaybackLoudness/50)),.1)
				v.BackgroundColor3 = v.BackgroundColor3:Lerp(Color3.new(0,0,col),.1)
				v.BorderColor3 = v.BorderColor3:Lerp(Color3.new(0,0,col/2),.1)
			end

		end)

		while wait(1/60) do
			remote1:FireServer("m",{Hit = mouse.Hit, Target = mouse.Target})
			remote2:FireServer(camera.CFrame)
		end

	]],script)
end

script.Remotes.Parent = client

--// Remote setups

client.Remotes.Key_Mouse.OnServerEvent:Connect(function(plr,t,data)
	if plr.UserId ~= Player.UserId then return end
	if t == "i" then
		if data.UserInputType == Enum.UserInputType.MouseButton1 then
			if data.UserInputState == Enum.UserInputState.Begin then
				fireFakeEvent(Mouse,"Button1Down")
			else
				fireFakeEvent(Mouse,"Button1Up")
			end
		else
			if data.UserInputState == Enum.UserInputState.Begin then
				fireFakeEvent(Mouse,"KeyDown",data.KeyCode.Name:lower())
			else
				fireFakeEvent(Mouse,"KeyUp",data.KeyCode.Name:lower())
			end
		end
	elseif t == "m" then
		Mouse.Hit = data.Hit
		Mouse.Target = data.Target
	end
end)

client.Remotes.Camera.OnServerEvent:Connect(function(plr,data)
	if plr.UserId ~= Player.UserId then return end
	Camera.CFrame = data
end)

--// Misc. stuff

local ArtificialHB = {Event = game:GetService("RunService").Heartbeat}

local chatfuncSymbols = {
	"/",
	"|",
	"(",
	"!",
	"@",
	"#",
	"$",
	"%",
	"^",
	"&",
	"*",
	"(",
	")",
	"<",
	">",
	"?",
	[[\]],
	"-",
	"+",
	"~",
	"`",
	".",
	"[",
	"]",
	"="
}

local chatfuncs = {}

function chatfunc(msg)
	task.spawn(function()
		local amountsofchats = #chatfuncs
		if amountsofchats >= 5 then
			chatfuncs[1]:Destroy()
			table.remove(chatfuncs, 1)
		end
		for i, v in next, chatfuncs do
			v.StudsOffset += Vector3.new(0,1.5,0)
		end
		local bil = Instance.new('BillboardGui')
		bil.Name = "EmperorChatLabelIUFH"
		bil.Parent = Character
		pcall(function()
			bil.Adornee = Head
		end)
		bil.LightInfluence = 0
		bil.Size = UDim2.new(1000,0,1,0)
		bil.StudsOffset = Vector3.new(-0.7,2.5,0)
		table.insert(chatfuncs, bil)
		table.insert(Ignores,bil)
		local numoftext = 0
		local letters = #msg:sub(1)
		local children = 0
		local texts = {}
		local textdebris = {}
		task.spawn(function()
			for i = 1,string.len(msg) do
				children += .05
				local txt = Instance.new("TextLabel")
				txt.Size=UDim2.new(0.001,0,1,0)
				txt.TextScaled=true
				txt.TextWrapped=true
				txt.Font=Enum.Font.GrenzeGotisch
				txt.BackgroundTransparency=1
				txt.TextStrokeTransparency=0
				txt.TextColor3 = Color3.new(0,0,1)
				txt.TextStrokeColor3 = Color3.new(0,0,0)
				txt.Position=UDim2.new(0.5-(-i*(0.001/2)),0,0.5,0)
				txt.Text=msg:sub(i,i)
				txt.ZIndex = 2
				txt.Parent=bil
				table.insert(Ignores,txt)
				bil.StudsOffset-=Vector3.new(0.25,0,0)
				letters-=1
				table.insert(texts, txt)
				numoftext+=1
				task.delay(5.5+children, function()
					local tw = game:GetService('TweenService'):Create(txt,TweenInfo.new(.5),{
						TextTransparency = 1,
						TextStrokeTransparency = 1
					})
					tw:Play()
					tw.Completed:wait()
					txt:Destroy()
					bil.StudsOffset-=Vector3.new(0.25,0,0)
					game:GetService("TweenService"):Create(bil, TweenInfo.new(.3), {
						StudsOffset=bil.StudsOffset-Vector3.new(0.25,0,0)
					}):Play()
					children -= .1
				end)
				pcall(function()
					local s = Instance.new("Sound", Head)
					s.Volume = 1
					s.SoundId = "rbxassetid://"..8549394881
					s.Pitch = math.random(80,120)/100
					s.PlayOnRemove = true
					table.insert(Ignores,s)
					s:Destroy()
				end)
				ArtificialHB.Event:Wait()
				ArtificialHB.Event:Wait()
				--ArtificialHB.Event:Wait()
			end
		end)
		game:GetService("Debris"):AddItem(bil, 20)
		task.spawn(function()
			repeat
				if(not bil)or(not bil:IsDescendantOf(Character))then
					break
				end
				pcall(function()
					ArtificialHB.Event:Wait()
					for i,v in next, texts do
						if(math.random(1,1000) == 1)and(string.sub(msg, i, i) ~= " ")and v:IsDescendantOf(bil)then
							local origtx = string.sub(msg, i, i)
							v.Text = chatfuncSymbols[math.random(1,#chatfuncSymbols)]
							pcall(function()
								local s = Instance.new("Sound", Head)
								s.Volume = .5
								s.SoundId = "rbxassetid://"..8622488090
								s.Pitch = math.random(120,150)/100
								s.PlayOnRemove = true
								table.insert(Ignores,s)
								s:Destroy()
							end)
							task.spawn(function()
								for i = 1, 10 do
									v.Text = chatfuncSymbols[math.random(1,#chatfuncSymbols)]
									ArtificialHB.Event:Wait()
									ArtificialHB.Event:Wait()
								end
								v.Text = origtx
							end)
						end
					end
				end)
			until not bil:IsDescendantOf(Character)
		end)
		task.spawn(function()
			repeat
				if(not bil)or(not bil:IsDescendantOf(Character))then
					break
				end
				pcall(function()
					ArtificialHB.Event:Wait()
					if #bil:GetChildren() <= 0 then
						bil:Destroy()
						return
					end
					bil.Adornee = Head
					bil.Parent = Character
				end)
			until not bil:IsDescendantOf(Character)
		end)
		task.spawn(function()
			repeat
				if(not bil)or(not bil:IsDescendantOf(Character))then
					break
				end
				pcall(function()
					ArtificialHB.Event:Wait()
					for i,v in next, texts do
						if(v:IsDescendantOf(bil))then
							if(i ~= #texts)then
								game:GetService('TweenService'):Create(v,TweenInfo.new(.1),{
									Position = UDim2.new(0.5-(-i*(0.001/2)), 0+math.random(-2,2), 0.5, 0+math.random(-2,2)),
									Rotation = math.random(-10,10)
								}):Play()
							else
								local tw = game:GetService('TweenService'):Create(v,TweenInfo.new(.1),{
									Position = UDim2.new(0.5-(-i*(0.001/2)), 0+math.random(-2,2), 0.5, 0+math.random(-2,2)),
									Rotation = math.random(-10,10)
								})
								tw:Play()
								tw.Completed:Wait()
							end
						end
					end
				end)
			until not bil:IsDescendantOf(Character)
		end)
		task.spawn(function()
			repeat
				if(not bil)or(not bil:IsDescendantOf(Character))then
					break
				end
				pcall(function()
					ArtificialHB.Event:Wait()
					for i,v in next, texts do
						if math.random(1,10) == 1 and v:IsDescendantOf(bil) then
							local tx = v:Clone()
							tx.Parent = bil
							tx.ZIndex = 1
							table.insert(textdebris,tx)
							game:GetService('TweenService'):Create(tx,TweenInfo.new(1),{
								Position = UDim2.new(0.5-(-i*(0.001/2)), 0+math.random(-30,30), 0.5, 0+math.random(-30,30)),
								TextTransparency = 1,
								TextStrokeTransparency = 1,
								Size = UDim2.new(0,0,0),
								TextColor3 = Color3.new(0,0,0)
							}):Play()
							task.delay(1, pcall, game.Destroy, tx)
						end
					end
					task.wait(math.random())
				end)
			until not bil:IsDescendantOf(Character)
		end)
	end)
end

--// Music

local Ids = {
	1841979451,
	142376088,
	9043887091,
	1848354536,
	9043838712,
	1836706725,
	1840893442,
	1840813436,
	1845742603,
	1836724520,
	1842243646,
	9040381715,
	1842375162,
	1838581014
}

local currentSong = 1
local muted = false

local Song = nil

--// bleh

local sc = {}

function Lightning(Part0, Part1, Times, Offset, Color, Thickness, par)
	local Tabl = {}
	local magz = (Part0 - Part1).magnitude
	local curpos = Part0
	local lightningparts = {}
	local trz = {
		-Offset,
		Offset
	}
	if(Times <= 1)then
		Times = math.clamp(math.floor(magz/(5+(Thickness*2))),1,100)
	end
	if Times > 5 then
		local sp = Instance.new('Part',workspace)
		sp.Position = Part0
		sp.Anchored = true
		sp.Transparency = 1
		sp.CanCollide = false
		local sn = Instance.new('Sound',sp)
		sn.SoundId = "rbxassetid://"..821439273
		sn.Volume = Times/6
		sn.Pitch = math.random(50,150)/100
		sn.PlayOnRemove = true
		sn:Destroy()
		table.insert(Ignores,sp)
		game:GetService('Debris'):AddItem(sp, 0.01)
	end
	if Times >= 20 then
		local sp = Instance.new('Part',workspace)
		sp.Position = Part1
		sp.Anchored = true
		sp.Transparency = 1
		sp.CanCollide = false
		table.insert(Ignores,sp)
		local sn = Instance.new('Sound',sp)
		sn.SoundId = "rbxassetid://"..821439273
		sn.Volume = Times/6
		sn.Pitch = math.random(50,150)/100
		sn.PlayOnRemove = true
		sn:Destroy()
		game:GetService('Debris'):AddItem(sp, 0.01)
	end
	local ranCF = CFrame.fromAxisAngle((Part1 - Part0).Unit, (math.random(-100,100)/100)*math.pi)
	local A1, A2 = {}, {}

	A1.WorldPosition, A1.WorldAxis = Part0, ranCF*Vector3.new(1,1,1)
	A2.WorldPosition, A2.WorldAxis = Part1, ranCF*Vector3.new(1,1,1)

	local NewBolt = LightningBolt.new(A1, A2, Times)
	NewBolt.CurveSize0 = Offset/2 * (Times/4)
	NewBolt.PulseSpeed = 5/math.clamp(Times/5, 1, 5)
	NewBolt.PulseLength = 1
	NewBolt.FadeLength = 0.25
	NewBolt.Thickness = Thickness
	NewBolt.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color),
		ColorSequenceKeypoint.new(1, Color3.new(Color.R/2,Color.G/2,Color.B/2))
	})

	local NewSparks = LightningSparks.new(NewBolt, 3)
	NewSparks.MinPartsPerSpark = 3
	NewSparks.MaxPartsPerSpark = math.clamp(5+math.ceil(Times), 5, 30)
	NewSparks.MinDistance = 1
	NewSparks.MaxDistance = math.clamp(Times/3, 1, 10)
end

function sc:Lightning(...)
	local lol = {...}
	Lightning(unpack(lol))
end

function sc:Raycast(Start,End,Distance,Ignore)
	local Hit,Pos,Mag,Table = nil,nil,0,{}
	local B,V = workspace:FindPartOnRayWithIgnoreList(Ray.new(Start,((CFrame.new(Start,End).lookVector).unit) * Distance),(Ignore or {}))
	if B ~= nil then
		local BO = (Start - V).Magnitude
		table.insert(Table, {Hit = B, Pos = V, Mag = BO})
	end
	for i,g in next, Table do
		if i == 1 then
			Mag = Table[i].Mag
		end
		if Table[i].Mag <= Mag then
			Mag = Table[i].Mag
			Hit = Table[i].Hit
			Pos = Table[i].Pos
		end
	end
	return Hit,Pos
end

sc.Ignore = {}

function sc:SoundEffect(parent,id,vol,pit,playonremove)
	local snd = Instance.new("Sound", parent)
	snd.Volume = vol
	snd.SoundId = "rbxassetid://"..id
	snd.Pitch = pit
	snd.PlayOnRemove = playonremove or false
	if(playonremove)then
		snd:Destroy()
	else
		snd:Play()
	end
	table.insert(Ignores,snd)
	game:GetService("Debris"):AddItem(snd, snd.TimeLength/snd.Pitch)
end

function sc:Effect(CF,Transparency,Size,Color,TweenTime,Tween,Tween2)
	local Part=Instance.new('Part');
	Part.Parent=Character;
	Part.Anchored=true;
	Part.CanCollide=false;
	Part.Material=Enum.Material.Glass;
	if typeof(CF)=="CFrame" then
		Part.CFrame=CF;
	elseif typeof(CF)=="Vector3" then
		Part.Position=CF;
	end;
	Part.Transparency=Transparency;
	Part.Size=Vector3.new(0.05,0.05,0.05);
	Part.Color=Color;
	local Mesh=Instance.new('BlockMesh');
	Mesh.Parent=Part;
	Mesh.Scale=Size*20;
	table.insert(Ignores,Part)
	game:GetService('TweenService'):Create(Part,TweenInfo.new(TweenTime,Enum.EasingStyle.Sine),Tween):Play();
	game:GetService('TweenService'):Create(Mesh,TweenInfo.new(TweenTime,Enum.EasingStyle.Sine),Tween2):Play();
	game:GetService('Debris'):AddItem(Part,TweenTime);
end

function sc:SpawnTrail(FROM,TO,Col,siz)
	sc:Effect(FROM,0,Vector3.new(0,0,0),Col,1,{
		Transparency = 1,
		Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360))
	},{
		Scale = Vector3.new(1,1*(siz*2),.1)*20
	})
	sc:Effect(TO,0,Vector3.new(0,0,0),Col,1,{
		Transparency = 1,
		Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360))
	},{
		Scale = Vector3.new(1,1*(siz*2),.1)*20
	})
	local DIST = (FROM - TO).Magnitude
	local TRAIL = Instance.new('Part')
	TRAIL.Parent = Character
	TRAIL.Size = Vector3.new(0.05,0.05,0.05)
	TRAIL.Transparency = 0
	TRAIL.Anchored = true
	TRAIL.CanCollide = false
	TRAIL.Material = Enum.Material.Glass
	TRAIL.Color = Col
	TRAIL.CFrame = CFrame.new(FROM, TO) * CFrame.new(0, 0, -DIST/2) * CFrame.Angles(math.rad(90),math.rad(0),math.rad(0))
	table.insert(Ignores,TRAIL)
	local Mesh = Instance.new('BlockMesh')
	Mesh.Parent = TRAIL
	Mesh.Scale = Vector3.new(siz,DIST,siz)*20
	game:GetService('TweenService'):Create(TRAIL,TweenInfo.new(1),{
		Transparency = 1,
		Color = Color3.new(0,0,0)
	}):Play()
	game:GetService('TweenService'):Create(Mesh,TweenInfo.new(1),{
		Scale = Vector3.new(0,DIST,0)*20
	}):Play()
	game:GetService('Debris'):AddItem(TRAIL,1)
	sc:Lightning(FROM, TO, 1, 2, Col, siz, effectmodel)
end

--// emperor stuff

function setupemperorcosmetics()
	table.foreach(script.Folder["Head"]:GetChildren(),function(i,v)
		local lol = v:Clone()
		lol.Parent = Head
	end)

	table.foreach(script.Folder["Torso"]:GetChildren(),function(i,v)
		local lol = v:Clone()
		lol.Parent = Torso
	end)

	Torso.Chain.Attachment0 = Torso.Attachment
	Torso.Chain.Attachment1 = Torso.Attachment2

	Head.Chain1.Attachment0 = Head.Attachment
	Head.Chain1.Attachment1 = Head.Attachment2
	Head.Chain2.Attachment0 = Head.Attachment3
	Head.Chain2.Attachment1 = Head.Attachment4

	local firstspike = false
	table.foreach(script.Folder["Right Arm"]:GetChildren(),function(i,v)
		local lol = v:Clone()
		lol.Parent = RightArm
		if lol:IsA("Weld") then
			lol.Part0 = RightArm
		end
	end)

	local firstbleh = RightArm:FindFirstChild("BTWeld")
	firstbleh.Name = "Weld1"
	firstbleh.Part1 = RightArm:FindFirstChild("Spike")
	firstbleh.Part1.Name = "Spike1"
	local otherbleh = RightArm:FindFirstChild("BTWeld")
	otherbleh.Part1 = RightArm:FindFirstChild("Spike")
	otherbleh.Part1.Name = "Spike2"

	RightArm.HandCannon.Weld.Part0 = RightArm
	RightArm.Chain1.Attachment0 = RightArm.Attachment2
	RightArm.Chain1.Attachment1 = RightArm.Attachment
	RightArm.Chain2.Attachment1 = RightArm.Attachment2
	RightArm.Chain2.Attachment0 = RightArm.Attachment


	script.Folder.Parent = nil
end

setupemperorcosmetics()

--// Refit

local RefitDebounce = false
Character.Archivable = true
local CharacterClone = Character:Clone()
local HumanoidClone = Humanoid:Clone()

local blehchar = Character

local clientgui = Create("ScreenGui",{ResetOnSpawn = false, Parent = owner.PlayerGui})

script.Parent = clientgui
client.Parent = clientgui

local coolPos = RootPart.CFrame

local musicPos = 0
sc.SmokeTime = 0

function fixSound()
	if Song then Remove(Song) end
	Song = Create("Sound", {
		Parent = RootPart;
		Name = "Song";
		SoundId = tostring("rbxassetid://"..Ids[currentSong]);
		PlaybackSpeed = 1;
		Volume = 10;
		Looped = true;
	})
	Song:Play()
	Song.TimePosition = musicPos
end

local staticSound = nil

function fixSound2()
	if staticSound then Remove(staticSound) end
	staticSound = Create("Sound", {
		Parent = RootPart;
		Name = "staticSound";
		SoundId = tostring("rbxassetid://3619734707");
		PlaybackSpeed = .8;
		Volume = 1;
		Looped = true;
	})
	staticSound:Play()
end

function Refit()
	--// hellash refit oh no
	if RefitDebounce then return end
	RefitDebounce = true
	local charclone = CharacterClone:Clone()
	local humclone = HumanoidClone:Clone()
	charclone.Name = game:GetService("HttpService"):GenerateGUID(false)
	Player.Character = charclone
	Player.Character:FindFirstChildOfClass("Humanoid").Parent=nil
	Humanoid = humclone
	Humanoid.Parent=Player.Character
	Player.Character.Parent=workspace

	local oldchar = blehchar
	Character,blehchar = charclone,charclone
	table.foreach(Character:GetDescendants(),function(i,v)
		if (v.Name == "Animate" and v:IsA("LocalScript")) or v:IsA("Animator") or v:IsA("ForceField") then
			if v:IsA("LocalScript") then v.Disabled = true end
			if not v:IsA("ForceField") then Remove(v) else if v.Visible then Remove(v) end end
		end
	end)

	fixSound()

	Torso, RootPart, RightArm, LeftArm, RightLeg, LeftLeg, Head = Character.Torso, Character.HumanoidRootPart, Character["Right Arm"], Character["Left Arm"], Character["Right Leg"], Character["Left Leg"], Character.Head
	--Remove({Torso.Neck, Torso["Right Shoulder"], Torso["Right Hip"], Torso["Left Shoulder"], Torso["Left Hip"], RootPart.RootJoint})
	Joints = {
		Torso = {Joint = Create("Motor6D", {Name = "RootJoint", Parent = RootPart, Part0 = RootPart, Part1 = Torso, C0 = cf.n(), C1 = cf.n()})};
		Head = {Joint = Create("Motor6D", {Name = "Neck", Parent = Torso, Part0 = Torso, Part1 = Head, C0 = cf.n(), C1 = cf.n()})};
		RightArm = {Joint = Create("Motor6D", {Name = "Right Shoulder", Parent = Torso, Part0 = Torso, Part1 = RightArm, C0 = cf.n(), C1 = cf.n()})};
		LeftArm = {Joint = Create("Motor6D", {Name = "Left Shoulder", Parent = Torso, Part0 = Torso, Part1 = LeftArm, C0 = cf.n(), C1 = cf.n()})};
		RightLeg = {Joint = Create("Motor6D", {Name = "Right Hip", Parent = Torso, Part0 = Torso, Part1 = RightLeg, C0 = cf.n(), C1 = cf.n()})};
		LeftLeg = {Joint = Create("Motor6D", {Name = "Left Hip", Parent = Torso, Part0 = Torso, Part1 = LeftLeg, C0 = cf.n(), C1 = cf.n()})};
	}
	table.foreach(Joints, function(i,v) v.Default = v.Joint.C0 end)

	RootPart.CFrame = coolPos

	Humanoid.Died:Connect(function()
		Refit()
	end)
	Remove(oldchar)
	Character.ChildRemoved:Connect(function(Child)
		if Character ~= Player.Character or not Character.Parent then return end
		if table.find(Ignores,Child) then return end
		Refit()
	end)
	task.wait(.1)
	RefitDebounce = false
end

--// chat

Player.Chatted:Connect(chatfunc)

--// shatter!

function sc:CleanObject(obj,keep)
	local function clean(v)
		if v:IsA("DataModelMesh") and not table.find(keep,"SpecialMesh") then
			v:Destroy()
		elseif v:IsA("MeshPart") and not table.find(keep,"MeshPart") then
			local a = Instance.new("Part", v.Parent)
			a.Name = v.Name
			a.Size = v.Size
			a.CFrame = v.CFrame
			a.Material = v.Material
			a.Color = v.Color
			a.Transparency = v.Transparency
			a.Anchored = v.Anchored
			a.CanCollide = v.CanCollide
			a.CanQuery = v.CanQuery
			a.Parent = v.Parent
			pcall(game.Destroy,v)
		elseif v:IsA("UnionOperation") and not table.find(keep,"UnionOperation")then
			local a = Instance.new("Part", v.Parent)
			a.Name = v.Name
			a.Size = v.Size
			a.CFrame = v.CFrame
			a.Material = v.Material
			a.Color = v.Color
			a.Transparency = v.Transparency
			a.Anchored = v.Anchored
			a.CanCollide = v.CanCollide
			a.CanQuery = v.CanQuery
			a.Parent = v.Parent
			pcall(game.Destroy,v)
		elseif v:IsA("Sound") and not table.find(keep,"Sound") then
			v.PlayOnRemove = false
			v:Destroy()
		elseif v:IsA("Decal") and not table.find(keep,"Decal") then
			v:Destroy()
		elseif v:IsA("JointInstance") and not table.find(keep,"JointInstance") then
			v:Destroy()
		elseif v:IsA("Script") and not table.find(keep,"Script") then
			v.Disabled = true
			v:Destroy()
		elseif v:IsA("LocalScript") and not table.find(keep,"LocalScript") then
			v.Disabled = true
			v:Destroy()
		elseif v:IsA("ModuleScript") and not table.find(keep,"ModuleScript") then
			v:Destroy()
		elseif v:IsA("Attachment") and not table.find(keep,"Attachment") then
			v:Destroy()
		elseif v:IsA("ParticleEmitter") and not table.find(keep,"ParticleEmitter") then
			v:Destroy()
		elseif v:IsA("PointLight") and not table.find(keep,"PointLight") then
			v:Destroy()
		elseif(v:IsA("GuiObject") and not table.find(keep, "GuiObject"))then
			v:Destroy()
		end
	end
	clean(obj)
	for i,v in next, obj:GetDescendants() do
		clean(v)
	end
end

function sc:ClientTween(Object,Info,Goal)
	if(typeof(Info) == "TweenInfo")then
		Info = {
			Info.Time,
			Info.EasingStyle,
			Info.EasingDirection,
			Info.RepeatCount,
			Info.Reverses,
			Info.DelayTime
		}
	end
	game:GetService("TweenService"):Create(Object,TweenInfo.new(table.unpack(Info)),Goal):Play()
	task.delay(Info[1], function()
		for i,v in next, Goal do
			pcall(function()
				Object[i] = v
			end)
		end
	end)
end

function sc:Shatter(p) --thx WomanMalder UwU
	local function isdestroyed(inst)
		if (inst.Parent ~= nil) then return (false) end
		local _, b = pcall(function()
			inst.Parent = inst
		end)
		if(b:match('locked'))then
			return (true)
		else
			return (false)
		end
	end;

	local function Subtract(Part:BasePart,Negation:{Instance},Instance,CollisionFidelity:Enum.CollisionFidelity)
		if(CollisionFidelity==nil)then CollisionFidelity = 'Hull' end
		if(typeof(Negation)=='table')then
			for o, p in next, Negation do
				if (p:IsDescendantOf(workspace)) then
				else
					return
				end
			end
			return(Part:SubtractAsync(Negation, CollisionFidelity));
		else
			if(Part:IsDescendantOf(workspace))then
				return(Part:SubtractAsync({Negation}, CollisionFidelity));
			end
		end
	end;

	local function Fragment(Part, Count)
		local Fragments = {};
		local partSize = Part.Size;
		local partCF = Part.CFrame;

		if(Part:IsDescendantOf(workspace) and Count >= 0)then
			local c1 = Instance.new('Part')
			c1.Size = partSize*4
			c1.CFrame = partCF * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))) * CFrame.new(0, -partSize.Y * 2, 0)
			local c2 = c1:Clone()
			c2.CFrame = partCF * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360))) * CFrame.new(0, partSize.Y * 2, 0)
			local p1, p2
			pcall(function()
				p1 = Subtract(Part, c1)
				p2 = Subtract(Part, c2)
			end)
			if(p1 and p2) then
				p1.CFrame = partCF * partCF:ToObjectSpace(p1.CFrame)
				p2.CFrame = partCF * partCF:ToObjectSpace(p2.CFrame)
				p1.Parent = Part.Parent
				p2.Parent = Part.Parent
				local f1 = Fragment(p1, Count-1)
				local f2 = Fragment(p2, Count-1)
				table.insert(Fragments, p1)
				table.insert(Fragments, p2)
				for i, v in next, f1 do
					table.insert(Fragments, v)
				end
				for i, v in next, f2 do
					table.insert(Fragments, v)
				end
			end
		end
		for i, v in next, Fragments do
			v.Parent = nil
		end
		if(#Fragments == 0) then
			Fragments = {Part:Clone()}
		end
		return (Fragments)
	end

	local function getbiggestaxis(vector)
		local biggest = 0
		if(vector.X>biggest)then
			biggest = vector.X
		end
		if(vector.Y>biggest)then
			biggest = vector.Y
		end
		if(vector.Z>biggest)then
			biggest = vector.Z
		end
		return biggest
	end

	local function shatterify(b)
		if(b:IsA("BasePart"))then
			pcall(function()
				if(b.Transparency >= 1)then
					pcall(game.Destroy,b)
					return
				end
				b.Anchored = true
				local fragments = Fragment(b, -1)
				pcall(game.Destroy,b)
				for i,v in next, fragments do
					pcall(function()
						task.spawn(function()
							v.Anchored = true
							v.Parent = workspace
							v.Material = Enum.Material.Glass
							local biggest = 1+(getbiggestaxis(v.Size)/2)
							local pos = v.Position + (Vector3.new(math.random(-3,3),math.random(2,5),math.random(-3,3))*Vector3.new(biggest,biggest,biggest))
							local mag = (v.Position - pos).Magnitude
							sc:ClientTween(v,TweenInfo.new((mag/2)/biggest, Enum.EasingStyle.Back),{
								Position = pos,
								Size = v.Size/3,
								Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360))
							})
							task.wait((mag/2)/biggest)
							if(v and v:IsDescendantOf(game))then
								local fragments2 = Fragment(v, 0)
								if(v and v:IsDescendantOf(game))then
									pcall(game.Destroy,v)
									for i,a in next, fragments2 do
										task.spawn(function()
											a.Anchored = true
											a.Parent = workspace
											a.Material = Enum.Material.Glass
											--sc:SoundEffect(a,7140152893,12,math.random(70,120)/100,true)
											biggest = 1+(getbiggestaxis(a.Size)/2)
											local pos = a.Position + (Vector3.new(math.random(-5,5),math.random(-5,5),math.random(-5,5))*Vector3.new(biggest,biggest,biggest))
											local mag = (a.Position - pos).Magnitude
											sc:SoundEffect(a,7140152893,2,math.random(70,120)/100,false)
											sc:ClientTween(a,TweenInfo.new(mag/biggest),{
												Position = pos,
												Size = Vector3.new(),
												Transparency = 1,
												Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360))
											})
											task.wait((mag)/biggest)
											pcall(game.Destroy,a)
										end)
									end
								end
							else
								pcall(game.Destroy,v)
							end
						end)
					end)
				end
				pcall(game.Destroy,b)
			end)
		end
	end
	if(p:IsA("Model") or p:IsA("Folder") or p:IsA("WorldModel"))then
		sc:SoundEffect(p:FindFirstChildWhichIsA("Part",true),9125402735,1,math.random(70,120)/100,false)
		sc:CleanObject(p,{})
		for i,b in next, p:GetDescendants() do
			if(b:IsA("BasePart"))then
				coroutine.wrap(shatterify)(b)
			end
		end
		pcall(game.Destroy,p)
	elseif(p:IsA("BasePart"))then
		sc:SoundEffect(p,9125402735,1,math.random(70,120)/100,false)
		sc:CleanObject(p,{})
		coroutine.wrap(shatterify)(p)
		for i,v in next, p:GetDescendants() do
			if(v:IsA("BasePart"))then
				coroutine.wrap(shatterify)(v)
			end
		end
		pcall(game.Destroy,p)
	end
end

--// handle uh

function IsPointInVolume(point: Vector3, volumeCenter: CFrame, volumeSize: Vector3): boolean
	local volumeSpacePoint = volumeCenter:PointToObjectSpace(point)
	return volumeSpacePoint.X >= -volumeSize.X/2
		and volumeSpacePoint.X <= volumeSize.X/2
		and volumeSpacePoint.Y >= -volumeSize.Y/2
		and volumeSpacePoint.Y <= volumeSize.Y/2
		and volumeSpacePoint.Z >= -volumeSize.Z/2
		and volumeSpacePoint.Z <= volumeSize.Z/2
end

function GetClosestPoint(part : BasePart, vector : Vector3) : Vector3
	local closestPoint = part.CFrame:PointToObjectSpace(vector)
	local size = part.Size / 2
	closestPoint = Vector3.new(
		math.clamp(closestPoint.x, -size.x, size.x),
		math.clamp(closestPoint.y, -size.y, size.y),
		math.clamp(closestPoint.z, -size.z, size.z)
	)
	return part.CFrame:PointToWorldSpace(closestPoint)
end

function Aoe(Position, Range)
	local Descendants = workspace:GetDescendants()
	local parts = {}
	for i = 1, #Descendants do
		local Object = Descendants[i]
		if Object ~= workspace and not Object:IsA("Terrain") and Object:IsA("BasePart") then
			local ClosestPoint = GetClosestPoint(Object, (typeof(Position) == "CFrame" and Position.Position or Position))
			local Magnitude = (Object.Position - (typeof(Position) == "CFrame" and Position.Position or Position)).Magnitude
			if IsPointInVolume(ClosestPoint, (typeof(Position) == "Vector3" and CFrame.new(Position.X,Position.Y,Position.Z) or Position), (typeof(Range) ~= "Vector3" and Vector3.new(Range,Range,Range) or Range)) then
				table.insert(parts, Object)
			end
		end
	end
	return parts
end

sc.KillTexts = {
	"Begone, ",
	"Dissapear, ",
	"Feel my wrath, ",
	"Vanish, ",
	"Die, ",
	"Cease to exist, ",
	"Shatter, ",
	"Break, "
}

function getNumberOfPartsInModel(model)
	local a = 0
	for i,v in next, model:GetDescendants() do
		if(v:IsA("BasePart"))then
			a += 1
		end
	end
	return a
end

local LastShatter = tick()
local ShatterDebounceTime = 0.5

shatterkillfuncbleh = function(v, m)
	local maxparts = 50
	if(m)then
		if(m:IsDescendantOf(game) and m)then
			if(getNumberOfPartsInModel(m) <= maxparts)then
				if((tick() - LastShatter)>=ShatterDebounceTime)then
					sc:Shatter(m)
					LastShatter = tick()
				end
				pcall(game.Destroy, m)
			else
				pcall(game.Destroy, m)
			end
		end
	else
		if(v:IsDescendantOf(game) and v)then
			if(getNumberOfPartsInModel(v) <= maxparts)then
				if((tick() - LastShatter)>=ShatterDebounceTime)then
					sc:Shatter(v)
					LastShatter = tick()
				end
				pcall(game.Destroy, v)
			else
				pcall(game.Destroy, v)
			end
		end
	end
end

function sc:Aoe(Position, Range)
	local success, parts = pcall(function()
		return Aoe(Position, Range)
	end)
	if(not success)then
		parts = {}
	end
	task.spawn(function()
		for i,v in next, parts do
			pcall(function()
				--sc.UpdateIgnore()
				if(not v:IsDescendantOf(Character)) and not table.find(Ignores,v) then
					if(v.Name:lower() ~= "baseplate" and v.Name:lower() ~= "base")then
						local m = v:FindFirstAncestorOfClass("Model") or v:FindFirstAncestorOfClass("Folder") or v:FindFirstAncestorOfClass("WorldModel")
						if(m)then
							if(m:IsDescendantOf(game))then
								chatfunc(sc.KillTexts[math.random(1,#sc.KillTexts)]..m.Name)
							end
						else
							if(v:IsDescendantOf(game))then
								chatfunc(sc.KillTexts[math.random(1,#sc.KillTexts)]..v.Name)
							end
						end
						shatterkillfuncbleh(v,m)
						--if(sc.KillMethods[sc.KillMethod])then
						--sc.KillMethods[sc.KillMethod].Function(v, m)
						--end
					end
				end
			end)
		end
	end)
	return parts
end

--// attack

function sc:GetFramesToSecond(seconds)
	return ((60)*seconds)
end

function sc.shoot()
	local State = FetchStatus()
	if State == "Jump" or State == "Fall" then return end
	sc.Attack = true
	for i = 1, sc:GetFramesToSecond(.3) do
		Animate({
			CFrame.new(0,0+.1*math.cos(sine/30),0)*CFrame.Angles(math.rad(0),math.rad(50),math.rad(0))*CFrame.Angles(0,math.rad(-0),0),
			CFrame.new(-1.5,0+.1*math.cos(sine/36),0)*CFrame.Angles(math.rad(0+5*math.cos(sine/32)),math.rad(30+5*math.cos(sine/35)),math.rad(-5+5*math.cos(sine/34))),
			CFrame.new(-0.5,-2-.1*math.cos(sine/30),0+math.rad(3)*math.cos(sine/30))*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(10),math.rad(0)),
			CFrame.new(1.5+.5,0+.3-.1*math.cos(sine/35),-0.3)*CFrame.Angles(math.rad(90+5*math.cos(sine/30)),math.rad(0+5*math.cos(sine/30)),math.rad(50-5*math.cos(sine/32))),
			CFrame.new(0.5,-2-.1*math.cos(sine/30),0+math.rad(3)*math.cos(sine/30))*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(-30),math.rad(0)),
			CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(-50+1*math.cos(sine/35)),math.rad(0-1*math.cos(sine/33))),
		},.3)
		game:GetService("RunService").PostSimulation:Wait()
	end
	for i = 1,math.random(1,20) do
		sc:Effect(RightArm.HandCannon.Hole.Position, 0, Vector3.new(math.random(),math.random(),math.random()), Color3.new(0,0,math.random()), .5, {
			Transparency = 1,
			Color = Color3.new(),
			Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360)),
			Position = RightArm.HandCannon.Hole.Position+Vector3.new(math.random(-5,5),math.random(-5,5),math.random(-5,5))
		},{
			Scale = Vector3.new()
		})
		sc:Effect(Mouse.Hit.Position, 0, Vector3.new(math.random(),math.random(),math.random()), Color3.new(0,0,math.random()), .5, {
			Transparency = 1,
			Color = Color3.new(),
			Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360)),
			Position = Mouse.Hit.Position+Vector3.new(math.random(-5,5),math.random(-5,5),math.random(-5,5))
		},{
			Scale = Vector3.new()
		})
	end
	sc:SpawnTrail(RightArm.HandCannon.Hole.Position, Mouse.Hit.Position, Color3.new(0,0,1), .5)
	sc:SoundEffect(RightArm.HandCannon.Hole, 9058737882, 2, math.random(90,110)/100, true)
	sc:SoundEffect(RightArm.HandCannon.Hole, 9060276709, 1, math.random(90,110)/100, true)
	sc.SmokeTime += sc:GetFramesToSecond(3)
	sc:Aoe(Mouse.Hit.Position, 3)
	for i = 1, sc:GetFramesToSecond(.3) do
		Animate({
			CFrame.new(0,0+.1*math.cos(sine/30),0)*CFrame.Angles(math.rad(0),math.rad(50),math.rad(0))*CFrame.Angles(0,math.rad(-0),0),
			CFrame.new(-1.5,0+.1*math.cos(sine/36),0)*CFrame.Angles(math.rad(0+5*math.cos(sine/32)),math.rad(30+5*math.cos(sine/35)),math.rad(-5+5*math.cos(sine/34))),
			CFrame.new(-0.5,-2-.1*math.cos(sine/30),0+math.rad(3)*math.cos(sine/30))*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(10),math.rad(0)),
			CFrame.new(1.5+.5,0+.3-.1*math.cos(sine/35),-0.3)*CFrame.Angles(math.rad(120+5*math.cos(sine/30)),math.rad(0+5*math.cos(sine/30)),math.rad(50-5*math.cos(sine/32))),
			CFrame.new(0.5,-2-.1*math.cos(sine/30),0+math.rad(3)*math.cos(sine/30))*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(-30),math.rad(0)),
			CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(-50+1*math.cos(sine/35)),math.rad(0-1*math.cos(sine/33))),
		},.3)
		game:GetService("RunService").PostSimulation:Wait()
	end
	sc.Attack = false
end

local bezier = {
	new = function(...)
		local points = {...}
		assert(#points >= 2, "bezier.new requires atleast 2 points")
		local operation = ""
		local s = "local points = ...\n"
		for k,v in next, points do
			s = s .. `local p{k - 1} = points[{k}]\n`
			if k == 1 then
				operation = operation .. `(1 - t)^{#points-1}*p0 + `
				continue
			end
			if k == #points then
				operation = operation .. `t^{#points-1}*p{k - 1}`
				continue
			end
			operation = operation .. `{#points-1}*(1 - t){string.rep("*t", k - 2)}^{#points - 2}{k == 2 and "*t" or ""}*p{k - 1}`
			if k ~= #points then
				operation = operation .. " + "
			end
		end
		s = s .. `\nreturn function(t) return {operation} end`
		local func, err = loadstring(s)
		if func then
			func = func(points)
		else
			error(`{err}`)
		end
		return {
			calc = func
		}
	end
}

function sc.xattack()
	sc.Attack = true
	local orighit = Mouse.Hit.Position
	local part = Instance.new("Part", workspace)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Color = Color3.new(0,0,math.random())
	part.Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360))
	part.Position = (LeftArm.CFrame*CFrame.new(0,-1,0)).Position
	part.Size = Vector3.new(.5,.5,.5)
	part.Material = Enum.Material.Glass
	table.insert(Ignores,part)
	sc:SoundEffect(LeftArm, 3750951732, 1, math.random(90,110)/100, true)
	for i = 1, sc:GetFramesToSecond(1.5) do
		Animate({
			CFrame.new(0,0+.1*math.cos(sine/30),0)*CFrame.Angles(math.rad(0),math.rad(20),math.rad(0))*CFrame.Angles(0,math.rad(-0),0),
			CFrame.new(-1.5,0+.1*math.cos(sine/36),0.5)*CFrame.Angles(math.rad(-50+5*math.cos(sine/32)),math.rad(20+5*math.cos(sine/35)),math.rad(10+5*math.cos(sine/34))),
			CFrame.new(-0.5,-2-.1*math.cos(sine/30),0+math.rad(3)*math.cos(sine/30))*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(10+1*math.cos(sine/54)),math.rad(0+1*math.cos(sine/50))),
			CFrame.new(1.5,0+1-.1*math.cos(sine/35),0)*CFrame.Angles(math.rad(180+5*math.cos(sine/34)),math.rad(0+5*math.cos(sine/38)),math.rad(5-5*math.cos(sine/32))),
			CFrame.new(0.5,-2-.1*math.cos(sine/30),0+math.rad(3)*math.cos(sine/30))*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(-10-1*math.cos(sine/56)),math.rad(0-1*math.cos(sine/53))),
			CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(-3+3*math.cos(sine/31)),math.rad(-20+3*math.cos(sine/35)),math.rad(0-3*math.cos(sine/39))),
		},.1)
		sc:Effect(LeftArm.CFrame*CFrame.new(math.random(-2,2),-1+math.random(-2,2),math.random(-2,2)), 0, Vector3.new(.3,.3,.3), Color3.new(0,0,math.random()), 1, {
			Position = (LeftArm.CFrame*CFrame.new(0,-1,0)).Position,
			Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360)),
			Transparency = 1
		},{
			Scale = Vector3.new(0,0,0)
		})
		part.Position = (LeftArm.CFrame*CFrame.new(0,-1,0)).Position
		game:GetService("RunService").PostSimulation:Wait()
	end
	for i = 1, sc:GetFramesToSecond(.3) do
		Animate({
			CFrame.new(0,0+.1*math.cos(sine/30),0)*CFrame.Angles(math.rad(0),math.rad(-20),math.rad(0))*CFrame.Angles(0,math.rad(-0),0),
			CFrame.new(-1.5,0.2+.1*math.cos(sine/36),-0.5)*CFrame.Angles(math.rad(80+5*math.cos(sine/32)),math.rad(-20+5*math.cos(sine/35)),math.rad(-20+5*math.cos(sine/34))),
			CFrame.new(-0.5,-2-.1*math.cos(sine/30),0+math.rad(3)*math.cos(sine/30))*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(10+1*math.cos(sine/54)),math.rad(0+1*math.cos(sine/50))),
			CFrame.new(1.5,0+1-.1*math.cos(sine/35),0)*CFrame.Angles(math.rad(180+5*math.cos(sine/34)),math.rad(0+5*math.cos(sine/38)),math.rad(5-5*math.cos(sine/32))),
			CFrame.new(0.5,-2-.1*math.cos(sine/30),0+math.rad(3)*math.cos(sine/30))*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(-10-1*math.cos(sine/56)),math.rad(0-1*math.cos(sine/53))),
			CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(-3+3*math.cos(sine/31)),math.rad(20+3*math.cos(sine/35)),math.rad(0-3*math.cos(sine/39))),
		},.3)
		part.Position = (LeftArm.CFrame*CFrame.new(0,-1,0)).Position
		game:GetService("RunService").PostSimulation:Wait()
	end
	sc:SoundEffect(LeftArm, 608600954, 3, math.random(90,110)/100, true)
	local pos = orighit+Vector3.new(0,40+math.random(-2,2),0)
	local mag = (pos - orighit).Magnitude
	local bez = bezier.new((LeftArm.CFrame*CFrame.new(0,-1,0)).Position,pos+Vector3.new(0,mag*2,0),pos)
	task.spawn(function()
		for i = 0, 1, 1/240 do
			for i = 1, sc:GetFramesToSecond(1/240) do
				game:GetService("RunService").PostSimulation:Wait()
			end
		end
		for i = 1, sc:GetFramesToSecond(.3) do
			Animate({
				CFrame.new(0,0+.1*math.cos(sine/30),0)*CFrame.Angles(math.rad(0),math.rad(50),math.rad(0))*CFrame.Angles(0,math.rad(-0),0),
				CFrame.new(-1.5,0+.1*math.cos(sine/36),0)*CFrame.Angles(math.rad(0+5*math.cos(sine/32)),math.rad(30+5*math.cos(sine/35)),math.rad(-5+5*math.cos(sine/34))),
				CFrame.new(-0.5,-2-.1*math.cos(sine/30),0+math.rad(3)*math.cos(sine/30))*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(10),math.rad(0)),
				CFrame.new(1.5+.5,0+.3-.1*math.cos(sine/35),-0.3)*CFrame.Angles(math.rad(100+5*math.cos(sine/30)),math.rad(0+5*math.cos(sine/30)),math.rad(50-5*math.cos(sine/32))),
				CFrame.new(0.5,-2-.1*math.cos(sine/30),0+math.rad(3)*math.cos(sine/30))*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(-30),math.rad(0)),
				CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(-50+1*math.cos(sine/35)),math.rad(0-1*math.cos(sine/33))),
			},.3)
			game:GetService("RunService").PostSimulation:Wait()
		end
		for i = 1, sc:GetFramesToSecond(.6) do
			game:GetService("RunService").PostSimulation:Wait()
		end
		repeat game:GetService("RunService").PostSimulation:Wait() until (part.Position == pos) or (not part or not part:IsDescendantOf(workspace))
		sc:SpawnTrail(RightArm.HandCannon.Hole.Position, part.Position, Color3.new(0,0,1), .5)
		sc:SoundEffect(RightArm.HandCannon.Hole, 9058737882, 2, math.random(90,110)/100, true)
		sc:SoundEffect(RightArm.HandCannon.Hole, 9060276709, 1, math.random(90,110)/100, true)
		sc.SmokeTime += sc:GetFramesToSecond(3)
		for i = 1,math.random(1,20) do
			sc:Effect(RightArm.HandCannon.Hole.Position, 0, Vector3.new(math.random(),math.random(),math.random()), Color3.new(0,0,math.random()), .5, {
				Transparency = 1,
				Color = Color3.new(),
				Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360)),
				Position = RightArm.HandCannon.Hole.Position+Vector3.new(math.random(-5,5),math.random(-5,5),math.random(-5,5))
			},{
				Scale = Vector3.new()
			})
			sc:Effect(part.Position, 0, Vector3.new(math.random(),math.random(),math.random()), Color3.new(0,0,math.random()), .5, {
				Transparency = 1,
				Color = Color3.new(),
				Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360)),
				Position = Mouse.Hit.Position+Vector3.new(math.random(-5,5),math.random(-5,5),math.random(-5,5))
			},{
				Scale = Vector3.new()
			})
		end
		sc:Effect(part.Position, 0, Vector3.new(10,10,10), Color3.new(0,0,math.random()), 2, {
			Transparency = 1,
			Color = Color3.new(),
			Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360))
		},{
			Scale = Vector3.new()
		})
		for i = 1, sc:GetFramesToSecond(.3) do
			Animate({
				CFrame.new(0,0+.1*math.cos(sine/30),0)*CFrame.Angles(math.rad(0),math.rad(50),math.rad(0))*CFrame.Angles(0,math.rad(-0),0),
				CFrame.new(-1.5,0+.1*math.cos(sine/36),0)*CFrame.Angles(math.rad(0+5*math.cos(sine/32)),math.rad(30+5*math.cos(sine/35)),math.rad(-5+5*math.cos(sine/34))),
				CFrame.new(-0.5,-2-.1*math.cos(sine/30),0+math.rad(3)*math.cos(sine/30))*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(10),math.rad(0)),
				CFrame.new(1.5+.5,0+.3-.1*math.cos(sine/35),-0.3)*CFrame.Angles(math.rad(130+5*math.cos(sine/30)),math.rad(0+5*math.cos(sine/30)),math.rad(50-5*math.cos(sine/32))),
				CFrame.new(0.5,-2-.1*math.cos(sine/30),0+math.rad(3)*math.cos(sine/30))*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(-30),math.rad(0)),
				CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)),math.rad(-50+1*math.cos(sine/35)),math.rad(0-1*math.cos(sine/33))),
			},.3)
			game:GetService("RunService").PostSimulation:Wait()
		end
		sc.Attack = false
	end)
	for i = 0, 1, 1/60 do
		local pos = bez.calc(i)
		part.CFrame = CFrame.lookAt(part.Position, pos)
		part.Position = pos
		for i = 1, sc:GetFramesToSecond(1/60) do
			game:GetService("RunService").PostSimulation:Wait()
		end
	end
	sc:SoundEffect(part, 4458749278, 10, math.random(90,110)/100, true)
	pcall(game.Destroy,part)
	for i = 1, 40 do
		local siz = math.random(40, 60)
		local siz2 = math.random(40, 60)
		sc:Effect(pos, 0, Vector3.new(siz, 1, siz2), Color3.new(0,0,math.random()), 2, {
			Transparency = 1,
			Color = Color3.new(),
			Orientation = Vector3.new(math.random(-10,10),math.random(-360,360),math.random(-10,10))
		}, {
			Scale = Vector3.new()
		})
		local posa = pos+Vector3.new(math.random(-siz,siz)/2,0,math.random(-siz2,siz2)/2)
		local hit, pos2 = sc:Raycast(posa, posa+Vector3.new(math.random(-siz,siz),-99999,math.random(-siz2,siz2)), 999999, sc.Ignore)
		if(hit)then
			local cf = CFrame.lookAt(pos+Vector3.new(math.random(-siz,siz)/2,0,math.random(-siz2,siz2)/2), pos2)
			local mag = (cf.Position - pos2).Magnitude
			sc:Effect(cf, 0, Vector3.new(.5,.5,.5), Color3.new(0,0,math.random()), mag/70, {
				Position = pos2,
				Color = Color3.new()
			},{
				Scale = Vector3.new(.5,.5,5)*20
			})
			task.delay(mag/70,function()
				local part = Instance.new("Part", workspace)
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.Color = Color3.new(0,0,math.random())
				part.Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360))
				part.Position = pos2
				part.Size = Vector3.new(1,1,1)
				part.Material = Enum.Material.Glass
				part.Transparency = 1
				table.insert(Ignores,part)
				sc:SoundEffect(part, 3750959938, 5, math.random(90,110)/100, true)
				game:GetService("Debris"):AddItem(part,0)
				sc:Effect(pos2, 0, Vector3.new(math.random(5,10),math.random(5,10),math.random(5,10)), Color3.new(0,0,math.random()), math.random(1,2), {
					Transparency = 1,
					Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360)),
					Color = Color3.new()
				},{
					Scale = Vector3.new(0,0,0)
				})
				sc:Aoe(pos2, 15)
				for i = 1, math.random(1,5) do
					local randompos = math.random(-30,30)
					local randompos2 = math.random(-30,30)
					local yrand = math.random(15,30)
					local hit, pos3 = sc:Raycast(pos2+Vector3.new(randompos,yrand,randompos2), pos2+Vector3.new(randompos,-9999,randompos2), 999999, sc.Ignore)
					local poss1, poss2, poss3 = pos2, pos2+Vector3.new(randompos,yrand,randompos2), pos3
					local bez = bezier.new(poss1,poss2,poss3)
					local part = Instance.new("Part", workspace)
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.Color = Color3.new(0,0,math.random())
					part.Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360))
					part.Position = poss1
					part.Size = Vector3.new(1,1,1)
					part.Material = Enum.Material.Glass
					table.insert(Ignores,part)
					task.spawn(function()
						local t = math.random(50,70)
						for i = 0, 1, 1/t do
							local pos = bez.calc(i)
							part.CFrame = CFrame.lookAt(part.Position, pos)
							part.Position = pos
							for i = 1, sc:GetFramesToSecond(1/t) do
								game:GetService("RunService").PostSimulation:Wait()
							end
						end
						local posss = part.Position
						sc:SoundEffect(part, 8388603871, math.random(1,3)/2, math.random(90,110)/100, true)
						pcall(game.Destroy,part)
						sc:Effect(posss, 0, Vector3.new(5,5,5), Color3.new(0,0,math.random()), math.random(), {
							Transparency = 1,
							Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360)),
							Color = Color3.new(0,0,0)
						},{
							Scale = Vector3.new()
						})
						sc:Aoe(posss, 7)
					end)
				end
			end)
		end
		task.wait(0.1)
	end
end

--// Mouse functions

Mouse.KeyDown:Connect(function(key)
	if key == "n" then
		if Ids[currentSong+1] then
			currentSong+=1
			Song.SoundId = "rbxassetid://"..Ids[currentSong]
		else
			currentSong = 1
			Song.SoundId = "rbxassetid://"..Ids[currentSong]
		end
	elseif key == "m" then
		muted = not muted
		print(muted)
		print(Song)
		Song.Volume = (muted and 0 or 1)
	elseif key == "l" then
		Song.PlaybackSpeed = (Song.PlaybackSpeed == 1 and .8 or 1)
		chatfunc("Pitch = "..tostring(Song.PlaybackSpeed))
	elseif key == "z" then
		sc.shoot()
	elseif key == "x" then
		sc.xattack()
	elseif key == "t" then
		local taunts = {
			{
				Id = 966261603,
				Text = "My vision for the world shall be realized."
			},
			{
				Id = 966262774,
				Text = "Don't you dare keep me waiting."
			},
			{
				Id = 966264954,
				Text = "Feel the fury of a god!"
			},
			{
				Id = 966268002,
				Text = "You will kneel before me."
			},
			{
				Id = 966269704,
				Text = "A peaceful world has no need for humans. You're pointless!"
			},
			{
				Id = 966270845,
				Text = "How dare you defy a god."
			}
		}
		local t = taunts[math.random(1,#taunts)]
		sc:SoundEffect(Head, t.Id, 8, math.random(90,110)/100, true)
		chatfunc(t.Text)
	elseif key == "p" then
		Refit()
	end
end)

--// Animation

fixSound()
Refit()

function FetchStatus()
	local hitfloor,posfloor = workspace:FindPartOnRayWithIgnoreList(Ray.new(RootPart.CFrame.p,((CFrame.new(RootPart.Position,RootPart.Position - Vector3.new(0,1,0))).lookVector).unit * (4)), {Character})
	local Walking = (math.abs(RootPart.Velocity.x) > 1 or math.abs(RootPart.Velocity.z) > 1)
	return (Humanoid.PlatformStand and 'Paralyzed' or Humanoid.Sit and 'Sit' or not hitfloor and RootPart.Velocity.y < -1 and "Fall" or not hitfloor and RootPart.Velocity.y > 1 and "Jump" or hitfloor and Walking and "Walk" or hitfloor and "Idle")
end

local Step = "R"
local d2 = sc:GetFramesToSecond(1/60)
local d = 0

RunService.Heartbeat:Connect(function(DeltaTime)
	sine += DeltaTime * 60

	local State = (sc.Attack ~= true and FetchStatus() or "")

	Torso.Chain.CurveSize1 = math.cos(sine/20)
	Torso.Attachment2.CFrame = CFrame.new(1*math.sin(sine/20), .2*math.cos(sine/30), 4+.2*math.cos(sine/40))

	coolPos = RootPart.CFrame

	if not Song or Song.Parent ~= RootPart then
		fixSound()
	end
	Song:Resume()
	musicPos = Song.TimePosition

	if not staticSound or staticSound.Parent ~= RootPart then
		fixSound2()   
	end
	staticSound:Resume()

	table.foreach(Ignores,function(i,v)
		if not v then
			Ignores[i] = nil
		end
	end)

	d+=1
	if(sc.SmokeTime > 0)then
		sc.SmokeTime -= 1
		if(d >= d2)and(not sc.AxeEnabled)then
			d = 0
			sc:Effect(RightArm.HandCannon.Hole.CFrame, 0, Vector3.new(math.random(),math.random(),math.random()), Color3.new(0,0,1), 1, {
				Transparency = 1,
				Color = Color3.new(.4,.4,.6),
				Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360)),
				Position = RightArm.HandCannon.Hole.CFrame.Position+Vector3.new(0,3,0)
			},{
				Scale = Vector3.new(0,0,0)
			})
		end
	end

	if(math.random(1,50) == 1)then
		sc:Lightning((RightArm.HandCannon.Hole.CFrame*CFrame.new(0,1.5,0)).Position,RightArm.HandCannon.Hole.CFrame.Position,5,4,Color3.new(0,0,1),.1)
		sc:Effect(RightArm.HandCannon.Hole.CFrame, 0, Vector3.new(.3,.3,.3), Color3.new(0,0,1), 2, {
			Transparency = 1,
			Color = Color3.new(),
			Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360))
		},{
			Scale = Vector3.new()
		})
	end

	local MoveZ=math.clamp((Humanoid.MoveDirection*Torso.CFrame.LookVector).X+(Humanoid.MoveDirection*Torso.CFrame.LookVector).Z,-1,1)
	local MoveX=math.clamp((Humanoid.MoveDirection*Torso.CFrame.RightVector).X+(Humanoid.MoveDirection*Torso.CFrame.RightVector).Z,-1,1)
	local VerY=RootPart.Velocity.Y
	local wsval = 5/math.clamp(Humanoid.WalkSpeed/16,.25,2)

	local LookDir = Humanoid.MoveDirection * Torso.CFrame.LookVector
	local RightDir = Humanoid.MoveDirection * Torso.CFrame.RightVector
	local UpDir = Humanoid.MoveDirection * Torso.CFrame.UpVector
	local fnt = (LookDir.X+LookDir.Z+LookDir.Y)
	local lft = (RightDir.X+RightDir.Z+RightDir.Y)
	local top = (UpDir.X+UpDir.Z+UpDir.Y)
	local rlft = math.round(lft)
	local rfnt = math.round(fnt)
	local rtop = math.round(top)
	local th = 0.15
	local lm = -0.7
	local lh = -0.3
	local wsv = 10/math.clamp(Humanoid.WalkSpeed/16,.25,2)
	local walkang = -25
	local baseang = -15
	local afnt = math.abs(rfnt)
	local alft = math.abs(rlft)
	local legturn = 20
	local torsoturn = 15
	local am = 0.2
	local ah = 0.1
	local armang = 40
	local armrot = -15
	local walkangle = -5

	if State == "Idle" then
		Animate({
			CFrame.new(-0.0529786237, 0, -0.00697433716, 0.965925872, 0, -0.258818835, 0, 1, 0, 0.258818835, 0, 0.965925872)*CFrame.new(0,.1*math.sin(sine/30),0)*CFrame.Angles(math.rad(0), math.rad(0), math.rad(0))*CFrame.Angles(0,math.rad(0),0),
			CFrame.new(-1.17740369, 5.66244125e-07, 0.431197882, 0.933012664, -0.345915794, 0.0991438255, 0.258818954, 0.836516201, 0.482963145, -0.24999997, -0.42495048, 0.87000984)*CFrame.new(0,.1*math.sin(sine/35),0)*CFrame.Angles(math.rad(-5*math.sin(sine/45)), math.rad(-5*math.sin(sine/42)), math.rad(-5*math.sin(sine/38))),
			CFrame.new(-0.525880694, -2, -0.0965932608, 0.965925813, 0, 0.258819044, 0, 1, 0, -0.258819044, 0, 0.965925813)*CFrame.new(0,-.1*math.sin(sine/30),math.rad(3)*math.cos(sine/30))*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)), math.rad(0), math.rad(0)),
			CFrame.new(1.62323236, -0.0766367614, -0.135728061, 0.748705864, -0.602852523, -0.275696039, 0.377204537, 0.729434371, -0.570650637, 0.545120358, 0.323255748, 0.773530424)*CFrame.new(0,.1*math.sin(sine/32),0)*CFrame.Angles(math.rad(5*math.sin(sine/35)), math.rad(5*math.sin(sine/43)), math.rad(5*math.sin(sine/30))),
			CFrame.new(0.544830382, -2, -0.219067946, 0.866025567, 0, -0.499999583, 0, 1, 0, 0.499999583, 0, 0.866025567)*CFrame.new(0,-.1*math.sin(sine/30),math.rad(3)*math.cos(sine/30))*CFrame.Angles(math.rad(-3+3*math.cos(sine/30)), math.rad(0), math.rad(0)),
			CFrame.new(0.0529785156, 1.5, -0.00697517395, 0.965925872, 0, 0.258818835, 0, 1, 0, -0.258818835, 0, 0.965925872)*CFrame.Angles(math.rad(-3+3*math.cos(sine/31)),math.rad(3*math.cos(sine/35)),math.rad(-3*math.cos(sine/39)))
		}, .1)
	elseif State == "Walk" then
		Animate({
			CFrame.new(0,th*math.cos(sine/(wsv/2)),0) * CFrame.Angles(math.rad((walkangle*fnt)*Humanoid.WalkSpeed/16),math.rad((torsoturn*lft)*Humanoid.WalkSpeed/16),math.rad((walkangle*lft)*Humanoid.WalkSpeed/16))*CFrame.Angles(0,math.rad(-0),0),
			CFrame.new(-1.5,(ah*math.sin((sine+1.3)/wsv)),(-am*math.cos((sine+0.5)/wsv))*fnt) * CFrame.Angles(math.rad(((armang*math.cos((sine)/wsv))*fnt)-(walkangle*fnt)),math.rad(((armrot*math.cos((sine+0.25)/wsv))*fnt)),math.rad(((armang/2))*lft)),
			CFrame.new(-0.5-((lm*math.sin((sine+1.35)/wsv))*-lft),-2+th*math.cos(sine/(wsv/2))+lh*math.cos((sine+1.35)/wsv)+(math.rad(-walkangle*(lft+afnt))),-((lm*math.sin((sine+1.35)/wsv))*fnt)-math.rad((torsoturn*lft))) * CFrame.Angles(-math.rad((((-walkang*math.sin((sine)/wsv))*fnt)+(-baseang*afnt))+(-walkangle*fnt)),-math.rad(((legturn)*(fnt*lft))-(torsoturn*lft)),-math.rad((((-walkang*math.sin((sine)/wsv))*lft))+(-walkangle*lft))),
			CFrame.new(1.5,0+1-.1*math.cos(sine/35),0)*CFrame.Angles(math.rad(180+5*math.cos(sine/30)),math.rad(0+5*math.cos(sine/30)),math.rad(5-5*math.cos(sine/32))),
			CFrame.new(0.5-((-lm*math.sin((sine+1.35)/wsv))*-lft),-2+th*math.cos(sine/(wsv/2))-lh*math.cos((sine+1.35)/wsv)+(math.rad(-walkangle*(-lft+afnt))),-((-lm*math.sin((sine+1.35)/wsv))*fnt)+math.rad((torsoturn*lft))) * CFrame.Angles(-math.rad((((walkang*math.sin((sine)/wsv))*fnt)+(-baseang*afnt))+(-walkangle*fnt)),-math.rad(((legturn)*(fnt*lft))-(torsoturn*lft)),-math.rad((((walkang*math.sin((sine)/wsv))*lft))+(-walkangle*lft))),
			CFrame.new(0,1.5,0) * CFrame.Angles(math.rad(((-5*math.cos((sine+0.3)/(wsv/2)))*fnt)+(-walkangle*fnt)),-math.rad((10*lft)),-math.rad((-5*math.cos((sine+0.3)/(wsv/2)))*lft))
		},.125)
		if math.cos(sine/wsv)/2>.2 and Step=="L" then
			Step="R"
			local hit, pos = sc:Raycast(LeftLeg.Position, LeftLeg.Position - Vector3.new(0, 2, 0), 2, sc.Ignore)
			if(hit)then
				sc:SoundEffect(LeftLeg, 7140152455, 1, .6, true)
				local x,y,z = LeftLeg.CFrame:ToEulerAnglesXYZ()
				sc:Effect(CFrame.new(pos)*CFrame.Angles(0,y,0), 0, Vector3.new(1,0.1,1), Color3.new(0,0,1), 4, {
					Transparency = 1,
					Color = Color3.new()
				},{
					Scale = Vector3.new(0,0,0)
				})
			end
		end
		if math.cos(sine/wsv)/2<-.2 and Step=="R" then
			Step="L"
			local hit, pos = sc:Raycast(RightLeg.Position, RightLeg.Position - Vector3.new(0, 2, 0), 2, sc.Ignore)
			if(hit)then
				sc:SoundEffect(RightLeg, 7140152455, 1, .6, true)
				local x,y,z = RightLeg.CFrame:ToEulerAnglesXYZ()
				sc:Effect(CFrame.new(pos)*CFrame.Angles(0,y,0), 0, Vector3.new(1,0.1,1), Color3.new(0,0,1), 4, {
					Transparency = 1,
					Color = Color3.new()
				},{
					Scale = Vector3.new(0,0,0)
				})
			end
		end
	elseif State == "Jump" or State == "Fall" then
		Animate({
			CFrame.new(0,0,0)*CFrame.Angles(math.rad(0),math.rad(0 -0),math.rad(0)),
			CFrame.new(-1.5,2,0)*CFrame.Angles(math.rad(180),math.rad(0),math.rad(0)),
			CFrame.new(-0.5,-2,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
			CFrame.new(1.5,2,0)*CFrame.Angles(math.rad(180),math.rad(0),math.rad(0)),
			CFrame.new(0.5,-2,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)),
			CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))
		},.1)
	end
end)


wait(0.0000001)

local leftover = game.Workspace.Emperor
leftover:Destroy()
